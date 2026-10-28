/*
 * Copyright (c) 2025 OceanBase.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#define USING_LOG_PREFIX STORAGE

#include "ob_text_daat_iter.h"

namespace oceanbase
{
namespace storage
{
int ObTextDaaTIter::init(const ObTextDaaTParam &param)
{
  int ret = OB_SUCCESS;
  if (OB_ISNULL(param.base_param_) || OB_ISNULL(param.dim_iters_) || OB_ISNULL(param.allocator_)
      || OB_ISNULL(param.relevance_collector_)) {
    ret = OB_INVALID_ARGUMENT;
  } else if (OB_FAIL(ObSRDaaTIterImpl::init(*param.base_param_, *param.dim_iters_,
                                            *param.allocator_, *param.relevance_collector_))) {
  } else if (nullptr != param.base_param_->relevance_expr_
             && OB_FAIL(bm25_param_estimator_.init(param.bm25_param_est_ctx_))) {
  } else {
    mode_flag_ = param.mode_flag_;
    function_lookup_mode_ = param.function_lookup_mode_;
  }
  return ret;
}

void ObTextDaaTIter::reset()
{
  bm25_param_estimator_.reset();
  // this class can know the type of dim_iters_, but ObSRDaaTIterImpl maybe not
  if (OB_NOT_NULL(dim_iters_)) {
    for (int64_t i = 0; i < dim_iters_->count(); ++i) {
      static_cast<ObTextRetrievalDaaTTokenIter *>(dim_iters_->at(i))->reset();
    }
  }
  ObSRDaaTIterImpl::reset();
}

void ObTextDaaTIter::reuse(const bool switch_tablet)
{
  if ((OB_NOT_NULL(dim_iters_) && 0 == dim_iters_->count())) {
    // do nothing
  } else {
    bm25_param_estimator_.reuse(switch_tablet);
  }
  if (OB_NOT_NULL(dim_iters_)) {
    for (int64_t i = 0; i < dim_iters_->count(); ++i) {
      static_cast<ObTextRetrievalDaaTTokenIter *>(dim_iters_->at(i))->reuse();
    }
  }
  ObSRDaaTIterImpl::reuse(switch_tablet);
}

int ObTextDaaTIter::pre_process()
{
  int ret = OB_SUCCESS;
  if (dim_iters_->count() == 0) {
    ret = OB_ITER_END;
  } else if (nullptr != iter_param_->relevance_expr_) {
    if (OB_FAIL(bm25_param_estimator_.do_estimation(*iter_param_->eval_ctx_))) {
    }
  }
  return ret;
}

int ObTextDaaTIter::do_one_merge_round(int64_t &count)
{
  // With at most three posting lists, selecting their smallest heads directly
  // avoids heap push/pop, item shifting and virtual merger calls for every hit.
  // Larger queries keep the loser-tree implementation.
  if (dim_iters_->count() > 3) {
    return ObSRDaaTIterImpl::do_one_merge_round(count);
  }
  int ret = OB_SUCCESS;
  const ObDatum **ids = iter_domain_ids_.get_data();
  int64_t *next = next_round_iter_idxes_.get_data();
  for (int64_t i = 0; OB_SUCC(ret) && i < next_round_cnt_; ++i) {
    const int64_t idx = next[i];
    auto *token_iter = static_cast<ObTextRetrievalDaaTTokenIter *>(dim_iters_->get_data()[idx]);
    if (OB_ISNULL(token_iter)) {
      ret = OB_ERR_UNEXPECTED;
    } else if (OB_FAIL(token_iter->get_next_row())) {
      if (ret == OB_ITER_END) {
        ids[idx] = nullptr;
        ret = OB_SUCCESS;
      }
    } else if (OB_FAIL(token_iter->get_curr_score(small_merge_scores_[idx]))) {
    } else if (OB_NOT_NULL(iter_param_->dim_weights_) &&
               FALSE_IT(small_merge_scores_[idx] = small_merge_scores_[idx] *
                   iter_param_->field_boost_ * iter_param_->dim_weights_->at(idx))) {
    } else if (OB_FAIL(token_iter->get_curr_id(ids[idx]))) {
    }
  }

  int64_t smallest = -1;
  ObSRMergeItem lhs;
  ObSRMergeItem rhs;
  for (int64_t i = 0; OB_SUCC(ret) && i < dim_iters_->count(); ++i) {
    if (ids[i] != nullptr) {
      int64_t cmp = 0;
      lhs.iter_idx_ = i;
      rhs.iter_idx_ = smallest;
      if (smallest < 0) {
        smallest = i;
      } else if (OB_FAIL(merge_cmp_.cmp(lhs, rhs, cmp))) {
      } else if (cmp < 0) {
        smallest = i;
      }
    }
  }

  double relevance = 0.0;
  bool need_project = false;
  if (OB_SUCC(ret) && smallest < 0) {
    ret = OB_ITER_END;
  } else if (OB_SUCC(ret)) {
    next_round_cnt_ = 0;
    // Equal document IDs must be collected in increasing iterator order, just
    // as in the simple merger, to preserve floating-point score accumulation.
    for (int64_t i = 0; OB_SUCC(ret) && i < dim_iters_->count(); ++i) {
      if (ids[i] != nullptr) {
        int64_t cmp = 0;
        lhs.iter_idx_ = i;
        rhs.iter_idx_ = smallest;
        if (i != smallest && OB_FAIL(merge_cmp_.cmp(lhs, rhs, cmp))) {
        } else if (cmp == 0) {
          if (OB_FAIL(relevance_collector_->collect_one_dim(i, small_merge_scores_[i]))) {
          } else {
            next[next_round_cnt_++] = i;
          }
        }
      }
    }
    if (OB_FAIL(ret)) {
    } else if (OB_FAIL(relevance_collector_->get_result(relevance, need_project))) {
    } else if (need_project && OB_FAIL(process_collected_row(*ids[smallest], relevance))) {
    } else if (need_project && iter_param_->need_filter() &&
               OB_FAIL(filter_on_demand(count, relevance, need_project))) {
    } else if (need_project && OB_FAIL(cache_result(count, *ids[smallest], relevance))) {
    }
  }
  return ret;
}

ObTextBMWIter::ObTextBMWIter()
  : ObSRBMWIterImpl(),
    bm25_param_estimator_() {}

void ObTextBMWIter::reuse(const bool switch_tablet)
{
  bm25_param_estimator_.reuse(switch_tablet);
  if (OB_NOT_NULL(dim_iters_)) {
    for (int64_t i = 0; i < dim_iters_->count(); ++i) {
      static_cast<ObTextRetrievalBlockMaxIter *>(dim_iters_->at(i))->reuse();
    }
  }
  ObSRBMWIterImpl::reuse(switch_tablet);
}

void ObTextBMWIter::reset()
{
  bm25_param_estimator_.reset();
  if (OB_NOT_NULL(dim_iters_)) {
    for (int64_t i = 0; i < dim_iters_->count(); ++i) {
      static_cast<ObTextRetrievalBlockMaxIter *>(dim_iters_->at(i))->reset();
    }
  }
  ObSRBMWIterImpl::reset();
}

int ObTextBMWIter::init(const ObTextDaaTParam &param)
{
  int ret = OB_SUCCESS;
  if (OB_ISNULL(param.base_param_) || OB_ISNULL(param.dim_iters_) || OB_ISNULL(param.allocator_)
      || OB_ISNULL(param.relevance_collector_)) {
    ret = OB_INVALID_ARGUMENT;
  } else if (OB_FAIL(ObSRBMWIterImpl::init(*param.base_param_, *param.dim_iters_,
                                           *param.allocator_, *param.relevance_collector_))) {
  } else if (OB_FAIL(bm25_param_estimator_.init(param.bm25_param_est_ctx_))) {
  }
  return ret;
}

int ObTextBMWIter::get_next_rows(const int64_t capacity, int64_t &count)
{
  int ret = OB_SUCCESS;
  if (IS_NOT_INIT) {
    ret = OB_NOT_INIT;
  } else if (dim_iters_->count() == 0) {
    ret = OB_ITER_END;
  } else if (OB_FAIL(bm25_param_estimator_.do_estimation(*iter_param_->eval_ctx_))) {
  }

  if (FAILEDx(ObSRBMWIterImpl::get_next_rows(capacity, count))) {
    if (OB_UNLIKELY(OB_ITER_END != ret)) {
    }
  }
  return ret;
}

int ObTextBMWIter::init_before_wand_process()
{
  int ret = OB_SUCCESS;
  if (OB_UNLIKELY(!bm25_param_estimator_.is_estimated())) {
    ret = OB_ERR_UNEXPECTED;
  }

  for (int64_t i = 0; OB_SUCC(ret) && i < dim_iters_->count(); ++i) {
    ObTextRetrievalBlockMaxIter *block_max_iter = static_cast<ObTextRetrievalBlockMaxIter *>(dim_iters_->at(i));
    if (OB_FAIL(block_max_iter->init_block_max_iter(
        bm25_param_estimator_.get_total_doc_cnt(), bm25_param_estimator_.get_avg_doc_token_cnt()))) {
    }
  }
  return ret;
}

} // namespace storage
} // namespace oceanbase
