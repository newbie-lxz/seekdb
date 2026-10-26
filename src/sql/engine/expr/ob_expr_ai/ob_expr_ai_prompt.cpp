
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

#define USING_LOG_PREFIX SQL_ENG

#include "ob_expr_ai_prompt.h"
#include <regex>
#include "ob_ai_func.h"
#include "lib/utility/utility.h"
#include "common/json_type/ob_json_common.h"

using namespace oceanbase::common;
using namespace oceanbase::sql;

namespace oceanbase
{
namespace sql
{

// 判断是否属于 TEXT / LONGTEXT 类型
static bool is_ai_prompt_text_type(const ObObjType type)
{
  return type == ObTinyTextType ||
         type == ObTextType ||
         type == ObMediumTextType ||
         type == ObLongTextType;
}

ObExprAIPrompt::ObExprAIPrompt(common::ObIAllocator &alloc)
    : ObFuncExprOperator(alloc,
                         T_FUN_SYS_AI_PROMPT,
                         N_AI_PROMPT,
                         MORE_THAN_ZERO,
                         VALID_FOR_GENERATED_COL,
                         NOT_ROW_DIMENSION)
{
}

ObExprAIPrompt::~ObExprAIPrompt()
{
}

// 参数类型推导
int ObExprAIPrompt::calc_result_typeN(
    ObExprResType &type,
    ObExprResType *types_stack,
    int64_t param_num,
    common::ObExprTypeCtx &type_ctx) const
{
  int ret = OB_SUCCESS;
  UNUSED(type_ctx);

  const ObObjType template_type = types_stack[0].get_type();

  // 第一个参数必须为字符串模板
  if (is_ai_prompt_text_type(template_type)) {
    // TEXT/LONGTEXT 保留原始类型，避免隐式转换为 VARCHAR
  } else if (ob_is_string_tc(template_type)) {
    types_stack[0].set_calc_type(ObVarcharType);
    types_stack[0].set_calc_collation_type(CS_TYPE_UTF8MB4_BIN);
  } else {
    ret = OB_ERR_INVALID_TYPE_FOR_OP;
  }

  // 检查模板后的所有参数
  for (int64_t i = 1; i < param_num && OB_SUCC(ret); i++) {
    const ObObjType arg_type = types_stack[i].get_type();

    if (is_ai_prompt_text_type(arg_type)) {
      // 保留 TEXT/LONGTEXT 原始类型以及 LOB 元数据
    } else if (ob_is_string_tc(arg_type)) {
      // 普通字符串沿用原来的 VARCHAR 计算逻辑
      types_stack[i].set_calc_type(ObVarcharType);
      types_stack[i].set_calc_collation_type(CS_TYPE_UTF8MB4_BIN);
    } else if (ob_is_json(arg_type)) {
      // JSON Array / Object 允许传入
    } else {
      ret = OB_ERR_INVALID_TYPE_FOR_OP;
    }
  }

  if (OB_SUCC(ret)) {
    type.set_json();
    type.set_length(
        (ObAccuracy::DDL_DEFAULT_ACCURACY[ObJsonType]).get_length());
  }

  return ret;
}

// AI_PROMPT 执行逻辑
int ObExprAIPrompt::eval_ai_prompt(
    const ObExpr &expr,
    ObEvalCtx &ctx,
    ObDatum &res)
{
  INIT_SUCC(ret);

  ObDatum *template_datum = NULL;
  ObExpr *arg0 = expr.args_[0];
  ObString template_str;

  ObJsonArray *args_array = NULL;
  ObJsonObject *prompt_object = NULL;

  ObEvalCtx::TempAllocGuard tmp_alloc_g(ctx);
  MultimodeAlloctor tmp_allocator(tmp_alloc_g.get_allocator());

  lib::ObMallocHookAttrGuard malloc_guard(
      lib::ObMemAttr(N_AI_PROMPT));

  // 读取模板字符串
  if (OB_FAIL(tmp_allocator.eval_arg(
          arg0, ctx, template_datum))) {
  } else if (OB_ISNULL(template_datum) ||
             template_datum->is_null()) {
    ret = OB_INVALID_ARGUMENT;
  } else if (OB_FAIL(
          ObTextStringHelper::read_real_string_data(
              ctx.exec_ctx_,
              tmp_allocator,
              *template_datum,
              arg0->datum_meta_,
              arg0->obj_meta_.has_lob_header(),
              template_str))) {
  }

  // 创建 JSON 参数数组
  if (OB_FAIL(ret)) {
  } else if (OB_FAIL(
          ObAIFuncJsonUtils::get_json_array(
              tmp_allocator, args_array))) {
  } else {

    // 遍历 AI_PROMPT 的参数
    for (int64_t i = 1;
         i < expr.arg_cnt_ && OB_SUCC(ret);
         i++) {

      ObDatum *datum = NULL;
      ObExpr *arg = expr.args_[i];

      ObString arg_str;
      ObJsonString *arg_json_str = NULL;

      if (OB_FAIL(
              tmp_allocator.eval_arg(arg, ctx, datum))) {
      } else if (OB_ISNULL(datum) ||
                 datum->is_null()) {
        ret = OB_ERR_INVALID_TYPE_FOR_OP;

      // 普通字符串以及 TEXT/LONGTEXT 参数
      } else if (
          ob_is_string_tc(arg->datum_meta_.type_) ||
          is_ai_prompt_text_type(arg->datum_meta_.type_)) {

        // 正确读取普通字符串或 LOB 数据
        if (OB_FAIL(
                ObTextStringHelper::read_real_string_data(
                    ctx.exec_ctx_,
                    tmp_allocator,
                    *datum,
                    arg->datum_meta_,
                    arg->obj_meta_.has_lob_header(),
                    arg_str))) {
        } else if (OB_FAIL(
                ObAIFuncJsonUtils::get_json_string(
                    tmp_allocator,
                    arg_str,
                    arg_json_str))) {
        } else if (OB_FAIL(
                args_array->append(arg_json_str))) {
        }

      // JSON Array / JSON Object 参数
      } else if (ob_is_json(arg->datum_meta_.type_)) {

        ObIJsonBase *json_base = NULL;
        ObIJsonBase *json_tree = NULL;
        ObString json_text;
        bool is_null = false;

        // 读取 JSON 参数
        if (OB_FAIL(
                ObJsonExprHelper::get_json_doc(
                    expr,
                    ctx,
                    tmp_allocator,
                    i,
                    json_base,
                    is_null))) {
        } else if (is_null ||
                   OB_ISNULL(json_base)) {
          ret = OB_ERR_INVALID_TYPE_FOR_OP;

        // 仅支持 JSON 数组和对象
        } else if (
            json_base->json_type() != ObJsonNodeType::J_ARRAY &&
            json_base->json_type() != ObJsonNodeType::J_OBJECT) {
          ret = OB_ERR_INVALID_TYPE_FOR_OP;

        // 将 JSON 序列化为字符串
        } else if (OB_FAIL(
                ObAIFuncJsonUtils::print_json_to_str(
                    tmp_allocator,
                    json_base,
                    json_text))) {

        // 重新解析为 JSON_TREE
        } else if (OB_FAIL(
                ObJsonBaseFactory::get_json_base(
                    &tmp_allocator,
                    json_text,
                    ObJsonInType::JSON_TREE,
                    ObJsonInType::JSON_TREE,
                    json_tree))) {

        } else if (OB_ISNULL(json_tree)) {
          ret = OB_ERR_UNEXPECTED;

        // 保留 JSON 数组/对象原有结构
        } else if (OB_FAIL(
                args_array->append(
                    static_cast<ObJsonNode *>(json_tree)))) {
        }

      } else {
        ret = OB_ERR_INVALID_TYPE_FOR_OP;
      }
    }
  }

  // 构造最终 Prompt JSON 对象
  if (OB_FAIL(ret)) {
  } else if (OB_FAIL(
          ObAIFuncPromptObjectUtils::construct_prompt_object(
              tmp_allocator,
              template_str,
              args_array,
              prompt_object))) {
  } else {

    ObString raw_str;

    if (OB_FAIL(
            prompt_object->get_raw_binary(
                raw_str,
                &tmp_allocator))) {
    } else if (OB_FAIL(
            ObJsonExprHelper::pack_json_str_res(
                expr,
                ctx,
                res,
                raw_str))) {
    }
  }

  return ret;
}

// 注册表达式运行时执行函数
int ObExprAIPrompt::cg_expr(
    ObExprCGCtx &expr_cg_ctx,
    const ObRawExpr &raw_expr,
    ObExpr &rt_expr) const
{
  UNUSED(expr_cg_ctx);
  UNUSED(raw_expr);

  int ret = OB_SUCCESS;
  rt_expr.eval_func_ = ObExprAIPrompt::eval_ai_prompt;

  return ret;
}

} // namespace sql
} // namespace oceanbase
