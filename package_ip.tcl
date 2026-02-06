# ==============================================================================
# Vivado 一键创建工程并打包 IP 脚本 (最终完美版)
# ==============================================================================

set project_name "wavelet_baseline_removal_prj"
set base_dir     "D:/project/my_ip_repository_prj/wavelet/float_sym4"
set project_dir  "$base_dir/$project_name"
set src_dir      "$base_dir/scr"
set top_module   "wavelet_baselibe_removal_top"
set part_name    "xczu9eg-ffvb1156-2-i"

# 1. 环境清理
if {[file exists $project_dir]} {
    file delete -force $project_dir
}
create_project $project_name $project_dir -part $part_name

# 2. 导入文件 (先导入文件，再设置模式)
set v_files  [glob -nocomplain "$src_dir/*.v"]
set vh_files [glob -nocomplain "$src_dir/*.vh"]

if {[llength $v_files] > 0} {
    import_files -norecurse -force $v_files
    if {[llength $vh_files] > 0} {
        import_files -norecurse -force $vh_files
    }
}

# 3. 解决 Hierarchy 报错：先设置为 None，设好 Top 后再 package
set_property source_mgmt_mode None [current_project]
set_property top $top_module [current_fileset]
update_compile_order -fileset sources_1

# 4. 打包 IP 核
# 使用 -force_update_compile_order 解决警告
ipx::package_project -root_dir $project_dir -vendor user.org -library user -taxonomy /UserIP -import_files -force_update_compile_order

# 5. 设置 IP 属性
set core [ipx::current_core]
set_property display_name "Wavelet Baseline Removal Top" $core
set_property vendor_display_name "MyProject" $core

# 注意：Vivado 2021.1 已经自动推断了接口，手动推断命令应为 ipx::infer_bus_interface
# 既然 log 显示已经 Infer 成功，我们直接进行最后保存即可。

# 6. 最终校验并保存
ipx::create_xgui_files [ipx::current_core]
ipx::update_checksums [ipx::current_core]
ipx::save_core [ipx::current_core]

puts "========================================================"
puts "  IP 打包已成功完成！"
puts "  你现在可以在其他工程的 IP Catalog 中添加以下目录了："
puts "  $project_dir"
puts "========================================================"