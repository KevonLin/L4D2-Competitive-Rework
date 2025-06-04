#if defined _multi_tank_anger_manager_included
#endinput
#endif
#define _multi_tank_anger_manager_included

/**
 * @brief 获取指定Tank的传递次数
 * @param client 要查询的客户端索引
 * @return 传递次数，-1表示无效Tank
 */
native int MTAM_GetTankPasses(int client);

/**
 * @brief 当Tank传递次数变化时触发
 * @param client Tank的客户端索引
 * @param passes 新的传递次数
 */
forward void MTAM_OnPassesChanged(int client, int passes);

public SharedPlugin __pl_multi_tank_anger_manager = 
{
    name = "multi_tank_anger_manager",
    file = "multi_tank_anger_manager.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};