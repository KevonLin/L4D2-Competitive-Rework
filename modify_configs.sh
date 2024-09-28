#! /bin/bash

# 定义文件夹路径
DIR="cfg/cfgogl/zonemodrv"

# 检查文件夹是否存在
if [ -d "$DIR" ]; then
    # 删除文件夹
    rm -r "$DIR"
    echo "Path $DIR has deleted."
else
    echo "Path $DIR does not exist."
    cp -r cfg/cfgogl/zonemod $DIR
    mv $DIR/zonemod.cfg $DIR/zonemodrv.cfg
    echo "Path $DIR has created."
fi

# 修改插件信息和目录信息
# 替换“ZoneMod - Competitive L4D2 Configuration”为“ZoneMod RV - Competitive L4D2 Configuration”
find cfg/cfgogl/zonemodrv/ -type f -name "*.cfg" -exec sed -i 's|// ZoneMod - Competitive L4D2 Configuration|// ZoneMod RV - Competitive L4D2 Configuration|g' {} \;

# 在“Author: Sir”下方添加“// Editor: Lin”
find cfg/cfgogl/zonemodrv/ -type f -name "*.cfg" -exec sed -i '/Author: Sir/a // Editor: Lin' {} \;

# 将 cfg\cfgogl\zonemodrv\ 目录下所有文件中的 /zonemod/ 替换为 /zonemodrv/
find cfg/cfgogl/zonemodrv/ -type f -name "*.cfg" -exec sed -i 's|/zonemod/|/zonemodrv/|g' {} \;

# 修改confogl.cfg文件中的l4d_ready_cfg_name "ZoneMod RV"
sed -i 's|l4d_ready_cfg_name "ZoneMod|l4d_ready_cfg_name "ZoneMod RV|g' cfg/cfgogl/zonemodrv/confogl.cfg
sed -i 's|exec cfgogl/zonemodrv/zonemod.cfg|exec cfgogl/zonemodrv/zonemodrv.cfg|g' cfg/cfgogl/zonemodrv/confogl.cfg


# 修改shared_cvars.cfg文件
# 将 confogl_addcvar sv_allow_lobby_connect_only 修改为 //confogl_addcvar sv_allow_lobby_connect_only
sed -i 's|confogl_addcvar sv_allow_lobby_connect_only|//confogl_addcvar sv_allow_lobby_connect_only|g' cfg/cfgogl/zonemodrv/shared_cvars.cfg

# 将 confogl_match_killlobbyres "1" 修改为 confogl_match_killlobbyres "0"
sed -i 's|confogl_match_killlobbyres          "1"|confogl_match_killlobbyres          "0"|g' cfg/cfgogl/zonemodrv/shared_cvars.cfg

# 在 confogl_addcvar director_tank_lottery_selection_time 3 下方添加两行新内容
sed -i '/confogl_addcvar director_tank_lottery_selection_time 3/a confogl_addcvar z_witch_damage_per_kill_hit 100\nconfogl_addcvar z_witch_personal_space 500' cfg/cfgogl/zonemodrv/shared_cvars.cfg

# 修改shared_plugins.cfg文件
# 在 sm plugins load optional/temphealthfix.smx 下方添加 sm plugins load optional/l4d_witch_damage_announce.smx
sed -i '/sm plugins load optional\/temphealthfix.smx/a sm plugins load optional/l4d_witch_damage_announce.smx' cfg/cfgogl/zonemodrv/shared_plugins.cfg

# 在 sm plugins load optional/l4d2_profitless_ai_tank.smx 下方添加 sm plugins load optional/l4d2_ultra_witch.smx
sed -i '/sm plugins load optional\/l4d2_profitless_ai_tank.smx/a sm plugins load optional/l4d2_ultra_witch.smx' cfg/cfgogl/zonemodrv/shared_plugins.cfg

# 在 cfg/cfgogl/zonemodrv/shared_plugins.cfg 文件中注释掉 sm plugins load optional/l4d_common_ragdolls_be_gone.smx
sed -i 's/^sm plugins load optional\/l4d_common_ragdolls_be_gone.smx/\/\/&/' cfg/cfgogl/zonemodrv/shared_plugins.cfg


# 修改shared_settings.cfg文件
# 在 confogl_addcvar vs_tank_rock_damage 24 行下方空一行添加
# // [l4d2_ultra_witch.smx]
# confogl_addcvar z_witch_damage 100
sed -i '/confogl_addcvar vs_tank_rock_damage 24/a \\\n// [l4d2_ultra_witch.smx]\nconfogl_addcvar z_witch_damage 100' cfg/cfgogl/zonemodrv/shared_settings.cfg

# 在 confogl_addcvar gfc_rock_rage_override 1 下边一行添加 confogl_addcvar gfc_rock_rage_override 1
sed -i '/confogl_addcvar gfc_rock_rage_override 1/a confogl_addcvar gfc_rock_rage_override 1' cfg/cfgogl/zonemodrv/shared_settings.cfg

# 在 confogl_addcvar l4d2_infected_ff_allow_tank 1 下边一行添加 confogl_addcvar l4d2_infected_ff_block_witch 1
sed -i '/confogl_addcvar l4d2_infected_ff_allow_tank 1/a confogl_addcvar l4d2_infected_ff_block_witch 1' cfg/cfgogl/zonemodrv/shared_settings.cfg

# 修改 confogl_addcvar sm_max_lerp 0.067 为 confogl_addcvar sm_max_lerp 0.100
sed -i 's|confogl_addcvar sm_max_lerp 0.067|confogl_addcvar sm_max_lerp 0.100|g' cfg/cfgogl/zonemodrv/shared_settings.cfg

# 修改 sm_killlobbyres 为 //sm_killlobbyres
sed -i 's|sm_killlobbyres|//sm_killlobbyres|g' cfg/cfgogl/zonemodrv/shared_settings.cfg

# 修改zonemodrv.cfg文件
# 1. 修改 confogl_addcvar sm_witch_can_spawn 0 为 confogl_addcvar sm_witch_can_spawn 1
sed -i 's|confogl_addcvar sm_witch_can_spawn 0|confogl_addcvar sm_witch_can_spawn 1|g' cfg/cfgogl/zonemodrv/zonemodrv.cfg

# 2. 修改 confogl_addcvar l4d_witch_percent 0 为 confogl_addcvar l4d_witch_percent 1
sed -i 's|confogl_addcvar l4d_witch_percent 0|confogl_addcvar l4d_witch_percent 1|g' cfg/cfgogl/zonemodrv/zonemodrv.cfg

# 3. 修改 autopause_enable 和 autopause_force 相关的设置
# 修改 confogl_addcvar autopause_enable 1 和 confogl_addcvar autopause_force 1
# 为 confogl_addcvar autopause_enable 0 和 confogl_addcvar autopause_force 0
sed -i 's|confogl_addcvar autopause_enable 1|confogl_addcvar autopause_enable 0|g' cfg/cfgogl/zonemodrv/zonemodrv.cfg
sed -i 's|confogl_addcvar autopause_force 1|confogl_addcvar autopause_force 0|g' cfg/cfgogl/zonemodrv/zonemodrv.cfg
