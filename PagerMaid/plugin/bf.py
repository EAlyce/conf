
import os
import sys
import tarfile
import shutil
import subprocess
import zipfile
from pathlib import Path
from os.path import exists, isfile
from traceback import format_exc
from typing import List, Optional, Tuple, Union
from contextlib import contextmanager

# 导入PagerMaid相关模块
from pagermaid.config import Config
from pagermaid.listener import listener
from pagermaid.enums import Client, Message
from pagermaid.utils import lang
from pagermaid.utils.bot_utils import upload_attachment

# 常量定义
DEFAULT_BACKUP_FILENAME = "pagermaid_backup.tar.gz"
EXCLUDED_FILES = ["pagermaid.session-journal", "pagermaid.session"]
TEMP_DIR_NAME = "temp_backup"


class BackupError(Exception):
    """备份操作相关的异常类"""
    pass


class FileOperationError(Exception):
    """文件操作相关的异常类"""
    pass


@contextmanager
def safe_file_operation(operation_name: str):
    """
    文件操作的安全上下文管理器
    
    Args:
        operation_name: 操作名称，用于错误消息
        
    Yields:
        None
        
    Raises:
        FileOperationError: 当文件操作失败时
    """
    try:
        yield
    except (IOError, OSError, tarfile.TarError, zipfile.BadZipFile) as e:
        raise FileOperationError(f"{operation_name}失败: {str(e)}")
    except Exception as e:
        raise FileOperationError(f"{operation_name}时发生未知错误: {str(e)}")


def get_program_dir() -> str:
    """
    获取程序当前工作目录
    
    Returns:
        str: 程序目录的绝对路径
        
    Raises:
        RuntimeError: 当获取目录失败时
    """
    try:
        result = subprocess.run(['pwd'], capture_output=True, text=True, check=True)
        return result.stdout.strip()
    except subprocess.CalledProcessError as e:
        raise RuntimeError(f"获取程序目录失败: {e}")


def ensure_dir_exists(directory: str) -> None:
    """
    确保目录存在，如不存在则创建
    
    Args:
        directory: 目录路径
    """
    if not os.path.exists(directory):
        os.makedirs(directory)


def check_paths_exist(paths: List[str]) -> None:
    """
    检查路径是否存在
    
    Args:
        paths: 路径列表
        
    Raises:
        FileNotFoundError: 当路径不存在时
    """
    for path in paths:
        if not os.path.exists(path):
            raise FileNotFoundError(f"{path} 不存在")


def create_archive(source_paths: List[str], output_filename: str, archive_type: str = "tar.gz") -> None:
    """
    创建压缩文件
    
    Args:
        source_paths: 源文件/目录路径列表
        output_filename: 输出文件名
        archive_type: 压缩类型，支持 "tar.gz" 和 "zip"
        
    Raises:
        FileOperationError: 当压缩操作失败时
        ValueError: 当压缩类型不支持时
    """
    check_paths_exist(source_paths)
    
    try:
        if archive_type == "tar.gz":
            with safe_file_operation("创建tar.gz压缩文件"):
                with tarfile.open(output_filename, "w:gz") as tar:
                    for source_path in source_paths:
                        tar.add(source_path, arcname=os.path.basename(source_path))
        elif archive_type == "zip":
            with safe_file_operation("创建zip压缩文件"):
                with zipfile.ZipFile(output_filename, "w") as zipf:
                    for source_path in source_paths:
                        if os.path.isdir(source_path):
                            pre_len = len(os.path.dirname(source_path))
                            for parent, dirnames, filenames in os.walk(source_path):
                                for filename in filenames:
                                    pathfile = os.path.join(parent, filename)
                                    arcname = pathfile[pre_len:].strip(os.path.sep)
                                    zipf.write(pathfile, arcname)
                        else:
                            zipf.write(source_path, os.path.basename(source_path))
        else:
            raise ValueError(f"不支持的压缩类型: {archive_type}")
    except Exception as e:
        raise FileOperationError(f"创建压缩文件失败: {str(e)}")


def extract_archive(archive_path: str, extract_dir: str, archive_type: str = "tar.gz") -> bool:
    """
    解压缩文件
    
    Args:
        archive_path: 压缩文件路径
        extract_dir: 解压目录
        archive_type: 压缩类型，支持 "tar.gz" 和 "zip"
        
    Returns:
        bool: 解压是否成功
        
    Raises:
        FileOperationError: 当解压操作失败时
        ValueError: 当压缩类型不支持时
    """
    ensure_dir_exists(extract_dir)
    
    try:
        if archive_type == "tar.gz":
            with safe_file_operation("解压tar.gz文件"):
                with tarfile.open(archive_path, "r:gz") as tar:
                    tar.extractall(path=extract_dir)
        elif archive_type == "zip":
            with safe_file_operation("解压zip文件"):
                with zipfile.ZipFile(archive_path, "r") as zipf:
                    zipf.extractall(extract_dir)
        else:
            raise ValueError(f"不支持的压缩类型: {archive_type}")
        return True
    except Exception as e:
        print(f"解压失败: {str(e)}")
        print(format_exc())
        return False


def clean_files_from_directory(directory: str, files_to_remove: List[str]) -> None:
    """
    从目录中删除指定文件
    
    Args:
        directory: 目录路径
        files_to_remove: 要删除的文件名列表
    """
    for root, dirs, files in os.walk(directory):
        for file_name in files:
            if file_name in files_to_remove:
                file_path = os.path.join(root, file_name)
                try:
                    os.remove(file_path)
                except OSError as e:
                    print(f"无法删除文件 {file_path}: {e}")


def process_backup(data_dir: str, plugins_dir: str, output_file: str, 
                  excluded_files: List[str], temp_dir: str) -> Tuple[str, str]:
    """
    处理备份流程：创建备份、清理敏感文件、重新打包
    
    Args:
        data_dir: 数据目录路径
        plugins_dir: 插件目录路径
        output_file: 输出文件路径
        excluded_files: 要排除的文件列表
        temp_dir: 临时目录路径
        
    Returns:
        Tuple[str, str]: 最终备份文件路径和备份文件夹路径
        
    Raises:
        BackupError: 当备份过程失败时
    """
    try:
        # 检查目录是否存在
        check_paths_exist([data_dir, plugins_dir])
        
        # 创建初始备份
        create_archive([data_dir, plugins_dir], output_file)
        
        # 确保临时目录存在
        ensure_dir_exists(temp_dir)
        
        # 解压到临时目录
        if not extract_archive(output_file, temp_dir):
            raise BackupError("解压备份文件失败")
        
        # 清理敏感文件
        clean_files_from_directory(temp_dir, excluded_files)
        
        # 删除原始备份
        os.remove(output_file)
        
        # 重新创建备份
        modified_backup = output_file.replace(".tar.gz", "_modified.tar.gz")
        create_archive([temp_dir], modified_backup)
        
        # 重命名为原始文件名
        os.rename(modified_backup, output_file)
        
        # 重命名临时目录为最终备份目录
        final_backup_folder = os.path.join(os.path.dirname(temp_dir), "pagermaid_backup")
        if os.path.exists(final_backup_folder):
            shutil.rmtree(final_backup_folder)
        os.rename(temp_dir, final_backup_folder)
        
        return output_file, final_backup_folder
    except Exception as e:
        # 清理临时文件
        if os.path.exists(temp_dir):
            shutil.rmtree(temp_dir)
        if os.path.exists(output_file) and "modified" in output_file:
            os.remove(output_file)
        raise BackupError(f"备份处理失败: {str(e)}")


async def restore_backup(backup_file: str, target_dir: str) -> None:
    """
    恢复备份到目标目录
    
    Args:
        backup_file: 备份文件路径
        target_dir: 目标目录路径
        
    Raises:
        BackupError: 当恢复过程失败时
    """
    try:
        # 解压备份文件
        if not extract_archive(backup_file, target_dir):
            raise BackupError("解压备份文件失败")
        
        # 删除下载的备份文件
        os.remove(backup_file)
        
        # 获取备份文件夹路径
        backup_folder = os.path.join(target_dir, "pagermaid_backup")
        if not os.path.exists(backup_folder):
            raise FileNotFoundError(f"{backup_folder} 文件夹不存在")
        
        # 将备份文件夹中的内容复制到目标目录
        for item in os.listdir(backup_folder):
            src_path = os.path.join(backup_folder, item)
            dest_path = os.path.join(target_dir, item)
            if os.path.isdir(src_path):
                shutil.copytree(src_path, dest_path, dirs_exist_ok=True)
            else:
                shutil.copy2(src_path, dest_path)
        
        # 删除备份文件夹
        shutil.rmtree(backup_folder)
    except Exception as e:
        raise BackupError(f"恢复备份失败: {str(e)}")


async def handle_file_upload(bot: Client, message: Message, file_paths: List[str]) -> None:
    """
    处理文件上传
    
    Args:
        bot: 客户端实例
        message: 消息实例
        file_paths: 文件路径列表
    """
    chat_id = message.chat.id
    total_files = len(file_paths)
    
    for index, file_path in enumerate(file_paths, 1):
        await message.edit(f"正在上传第 {index}/{total_files} 个文件")
        
        if not exists(file_path):
            await message.edit(f"文件不存在: {file_path}")
            continue
            
        try:
            if isfile(file_path):
                await bot.send_document(chat_id, file_path, force_document=True)
            else:
                # 对于目录，创建临时zip文件
                token = os.path.basename(file_path)
                temp_zip = f"/tmp/{token}.zip"
                
                # 创建zip文件
                create_archive([file_path], temp_zip, archive_type="zip")
                
                # 发送文件
                await bot.send_document(chat_id, temp_zip, force_document=True)
                
                # 清理临时文件
                os.remove(temp_zip)
        except Exception as e:
            await message.edit(f"上传文件 {file_path} 失败: {str(e)}")
            
    await message.edit("上传完毕")


async def handle_file_download(message: Message, save_path: str) -> None:
    """
    处理文件下载
    
    Args:
        message: 消息实例
        save_path: 保存路径
    """
    reply = message.reply_to_message
    
    if not reply:
        await message.edit("未回复消息")
        return
        
    file_path = Path(save_path)
    if exists(file_path):
        await message.edit("路径已存在文件")
        return
        
    await message.edit("下载中...")
    try:
        _file = await reply.download(file_name=save_path)
        await message.edit(f"保存成功, 保存路径 `{save_path}`")
    except Exception as e:
        await message.edit(f"无法下载此类型的文件: {str(e)}")


@listener(outgoing=True, command="bf",
          description="将data和plugins文件夹打包成pagermaid_backup.tar.gz，删除备份包中的特定文件，然后重新打包并上传到收藏夹")
async def backup_and_clean(bot: Client, message: Message):
    """
    备份命令处理函数
    
    将data和plugins文件夹打包，删除敏感文件，重新打包并上传到收藏夹
    
    Args:
        bot: 客户端实例
        message: 消息实例
    """
    try:
        await message.edit("正在创建备份...")
        
        # 获取程序目录
        program_dir = get_program_dir()
        
        # 设置路径
        data_dir = os.path.join(program_dir, "data")
        plugins_dir = os.path.join(program_dir, "plugins")
        backup_file = os.path.join(program_dir, DEFAULT_BACKUP_FILENAME)
        temp_dir = os.path.join(program_dir, TEMP_DIR_NAME)
        
        # 处理备份
        backup_file, _ = process_backup(
            data_dir, 
            plugins_dir, 
            backup_file, 
            EXCLUDED_FILES, 
            temp_dir
        )
        
        # 上传备份
        await message.edit("备份创建完成，正在上传到收藏夹...")
        await bot.send_document("me", backup_file, force_document=True)
        await message.edit("备份完成并已上传到收藏夹")
        
    except Exception as e:
        error_message = f"备份失败: {str(e)}"
        await message.edit(error_message)


@listener(outgoing=True, command="hf",
          description="释放pagermaid_backup文件夹到程序根目录，并删除原pagermaid_backup文件夹")
async def release_backup_folder(message: Message):
    """
    恢复备份命令处理函数
    
    下载并解压备份文件，将文件释放到程序根目录
    
    Args:
        message: 消息实例
    """
    reply = message.reply_to_message

    if not reply or not reply.document or ".tar.gz" not in reply.document.file_name:
        return await message.edit("请回复一个.tar.gz文件以进行恢复。")

    try:
        await message.edit("下载中...")
        backup_file = await reply.download()  # 下载文件

        await message.edit("解压中...")
        program_dir = get_program_dir()
        
        # 恢复备份
        await restore_backup(backup_file, program_dir)
        
        completion_message = "备份已恢复请 `,restart`"
        await message.edit(completion_message)
    except Exception as e:
        error_message = f"释放失败: {str(e)}"
        await message.edit(error_message)


@listener(
    command="transfer",
    description="上传 / 下载文件",
    parameters="upload [filepath] 或 download [filepath]",
)
async def transfer(bot: Client, message: Message):
    """
    文件传输命令处理函数
    
    上传文件到聊天或下载文件到指定路径
    
    Args:
        bot: 客户端实例
        message: 消息实例
    """
    params = message.parameter
    if len(params) < 2:
        message: Message = await message.edit(
            "参数缺失，请使用 `upload [filepath (包括扩展名)]` 或 `download [filepath (包括扩展名)]`"
        )
        await message.delay_delete(3)
        return
        
    # 合并第二个参数之后的所有内容
    params[1] = " ".join(params[1:])
    file_list = params[1].split("\n")
    
    try:
        if params[0] == "upload":
            await handle_file_upload(bot, message, file_list)
        elif params[0] == "download":
            if len(file_list) > 0:
                await handle_file_download(message, file_list[0])
            else:
                await message.edit("未提供保存路径")
        else:
            await message.edit("未知命令，请使用 `upload [filepath]` 或 `download [filepath]`")
    except Exception as e:
        await message.edit(f"操作失败: {str(e)}")
    
    await message.delay_delete(3)

