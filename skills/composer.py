"""
多技能组合器
合并多个技能的结果，去重和排序
"""
import logging
from typing import List, Dict
from difflib import SequenceMatcher

from main import Call2Response, VisualData, StrategyItem

logger = logging.getLogger(__name__)


def _similarity(text1: str, text2: str) -> float:
    """
    计算两个文本的相似度
    
    Args:
        text1: 文本1
        text2: 文本2
        
    Returns:
        float: 相似度（0-1）
    """
    return SequenceMatcher(None, text1.lower(), text2.lower()).ratio()


def compose_results(skill_results: List[Dict]) -> Call2Response:
    """
    组合多个技能的结果
    
    Args:
        skill_results: 技能执行结果列表，每个元素包含：
            {
                "skill_id": "...",
                "result": Call2Response,
                "priority": 100,
                "confidence": 0.95
            }
        
    Returns:
        Call2Response: 合并后的结果
    """
    if not skill_results:
        raise ValueError("技能结果列表为空")
    
    # 过滤掉失败的结果
    successful_results = [r for r in skill_results if r.get("success", False) and r.get("result")]
    
    if not successful_results:
        # 如果所有技能都失败，返回第一个失败的结果（如果有）
        if skill_results:
            raise Exception(f"所有技能执行失败，最后一个错误: {skill_results[-1].get('error_message', '未知错误')}")
        else:
            raise ValueError("没有可用的技能结果")
    
    logger.info(f"开始组合 {len(successful_results)} 个技能的结果")
    
    # 合并 strategies
    all_strategies = []
    for skill_result in successful_results:
        result = skill_result.get("result")
        if result and result.strategies:
            for strategy in result.strategies:
                all_strategies.append({
                    "strategy": strategy,
                    "priority": skill_result.get("priority", 0),
                    "confidence": skill_result.get("confidence", 0.5),
                    "skill_id": skill_result.get("skill_id", "unknown")
                })
    
    # 去重：基于 title 和 content 相似度
    unique_strategies = []
    seen_titles = set()
    
    for item in all_strategies:
        strategy = item["strategy"]
        title = strategy.title.lower().strip()
        
        # 检查是否与已有策略相似
        is_duplicate = False
        for seen_title in seen_titles:
            if _similarity(title, seen_title) > 0.8:  # 相似度阈值 0.8
                is_duplicate = True
                logger.debug(f"策略去重: '{strategy.title}' 与 '{seen_title}' 相似")
                break
        
        if not is_duplicate:
            seen_titles.add(title)
            unique_strategies.append(item)
    
    # 按 priority 和 confidence 排序
    unique_strategies.sort(key=lambda x: (x["priority"], x["confidence"]), reverse=True)
    
    # 转换为 StrategyItem 列表
    final_strategies = [item["strategy"] for item in unique_strategies]
    
    logger.info(f"策略合并完成: 原始 {len(all_strategies)} 个，去重后 {len(final_strategies)} 个")
    
    # 合并 visual 数据
    all_visuals = []
    for skill_result in successful_results:
        result = skill_result.get("result")
        if result and result.visual:
            for visual in result.visual:
                all_visuals.append(visual)
    
    # 按 transcript_index 排序
    all_visuals.sort(key=lambda x: x.transcript_index)
    
    # 限制数量（最多 5 个）
    if len(all_visuals) > 5:
        logger.warning(f"关键时刻数量过多 ({len(all_visuals)} 个)，只保留前 5 个")
        all_visuals = all_visuals[:5]
    
    logger.info(f"视觉数据合并完成: {len(all_visuals)} 个关键时刻")
    
    # 构建最终结果
    return Call2Response(
        visual=all_visuals,
        strategies=final_strategies
    )
