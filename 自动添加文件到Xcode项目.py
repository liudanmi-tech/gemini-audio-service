#!/usr/bin/env python3
"""
自动添加文件到 Xcode 项目的脚本
使用方法：python3 自动添加文件到Xcode项目.py <项目路径>
"""

import sys
import os
import re
import shutil
from pathlib import Path

def find_xcode_project_files(directory):
    """查找 Xcode 项目文件"""
    xcodeproj_files = []
    for root, dirs, files in os.walk(directory):
        for dir_name in dirs:
            if dir_name.endswith('.xcodeproj'):
                xcodeproj_files.append(os.path.join(root, dir_name))
    return xcodeproj_files

def add_file_to_xcode_project(project_path, file_path, target_name=None):
    """
    添加文件到 Xcode 项目
    注意：这是一个简化版本，实际应该使用 xcodeproj 库或手动修改 project.pbxproj
    """
    project_file = os.path.join(project_path, 'project.pbxproj')
    
    if not os.path.exists(project_file):
        print(f"❌ 找不到项目文件: {project_file}")
        return False
    
    print(f"📝 项目文件: {project_file}")
    print(f"📄 要添加的文件: {file_path}")
    print("")
    print("⚠️  注意：自动修改 Xcode 项目文件可能比较复杂且容易出错")
    print("建议使用以下方法之一：")
    print("")
    print("方法1：在 Xcode 中手动添加")
    print("  1. 打开 Xcode 项目")
    print("  2. 右键点击目标文件夹 → Add Files to \"项目名\"...")
    print(f"  3. 选择文件: {file_path}")
    print("  4. 勾选 'Copy items if needed' 和 'Add to targets'")
    print("")
    print("方法2：使用命令行工具")
    print("  如果安装了 xcodeproj gem，可以使用：")
    print(f"  xcodeproj add-file {project_path} {file_path}")
    print("")
    
    return False

def main():
    # 查找 Xcode 项目
    print("🔍 正在查找 Xcode 项目文件...")
    print("")
    
    # 在常见位置查找
    search_paths = [
        os.path.expanduser("~/Desktop"),
        os.path.expanduser("~/Documents"),
        os.path.expanduser("~/Projects"),
    ]
    
    all_projects = []
    for search_path in search_paths:
        if os.path.exists(search_path):
            projects = find_xcode_project_files(search_path)
            all_projects.extend(projects)
    
    if all_projects:
        print(f"✅ 找到 {len(all_projects)} 个 Xcode 项目：")
        for i, project in enumerate(all_projects, 1):
            print(f"  {i}. {project}")
        print("")
    else:
        print("⚠️  未找到 Xcode 项目文件")
        print("")
    
    # 要添加的文件
    source_file = os.path.join(
        os.path.dirname(__file__),
        "iOS_Code_Files",
        "TaskDetailResponse.swift"
    )
    
    if not os.path.exists(source_file):
        print(f"❌ 源文件不存在: {source_file}")
        return
    
    print(f"📄 源文件: {source_file}")
    print("")
    print("=" * 60)
    print("由于 Xcode 项目文件的复杂性，建议手动添加文件")
    print("=" * 60)
    print("")
    print("快速操作步骤：")
    print("")
    print("1. 打开 Xcode 项目")
    print("2. 在项目导航器中找到存放 Swift 文件的文件夹")
    print("3. 右键点击文件夹 → 'Add Files to \"项目名\"...'")
    print(f"4. 选择文件: {source_file}")
    print("5. 勾选 'Copy items if needed' 和 'Add to targets'")
    print("6. 点击 'Add'")
    print("")
    print("或者使用拖拽方式：")
    print("1. 打开 Finder，导航到文件位置")
    print("2. 将文件拖拽到 Xcode 项目导航器")
    print("3. 在弹出对话框中勾选相应选项")
    print("")

if __name__ == "__main__":
    main()
