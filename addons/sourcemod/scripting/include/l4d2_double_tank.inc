#if defined _l4d2_double_tank_included
#endinput
#endif
#define _l4d2_double_tank_included

/**
 * @brief Gets the current number of tank control passes
 * @return Number of passes since last reset
 */
native int L4D2_GetTankPassCount();

public SharedPlugin __pl_l4d2_double_tank = 
{
    name = "l4d2_double_tank",
    file = "l4d2_double_tank.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};