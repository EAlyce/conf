import os
import sys
import tarfile
import shutil
import subprocess
import zipfile
from pathlib import Path
from os.path import exists, isfile
from traceback import format_exc
from typing import List, Tuple
from contextlib import contextmanager

from pagermaid.config import Config
from pagermaid.listener import listener
from pagermaid.enums import Client, Message
from pagermaid.utils import lang
from pagermaid.utils.bot_utils import upload_attachment

DEFAULT_BACKUP_FILENAME = "pagermaid_backup.tar.gz"
EXCLUDED_FILES = ["pagermaid.session-journal", "pagermaid.session"]
TEMP_DIR_NAME = "temp_backup"


class BackupError(Exception):
    pass


class FileOperationError(Exception):
    pass


@contextmanager
def safe_file_operation(operation_name: str):
    try:
        yield
    except (IOError, OSError, tarfile.TarError, zipfile.BadZipFile) as e:
        raise FileOperationError(f"{operation_name}失败: {str(e)}")
    except Exception as e:
        raise FileOperationError(f"{operation_name}时发生未知错误: {str(e)}")


def get_program_dir() -> str:
    try:
        result = subprocess.run(['pwd'], capture_output=True, text=True, check=True)
        return result.stdout.strip()
    except subprocess.CalledProcessError as e:
        raise RuntimeError(f"获取程序目录失败: {e}")


def ensure_dir_exists(directory: str) -> None:
    if not os.path.exists(directory):
        os.makedirs(directory)


def check_paths_exist(paths: List[str]) -> None:
    for path in paths:
        if not os.path.exists(path):
            raise FileNotFoundError(f"{path} 不存在")


def create_archive(source_paths: List[str], output_filename: str, archive_type: str = "tar.gz") -> None:
    check_paths_exist(source_paths)
    try:
        if archive_type == "tar.gz":
            with safe_file_operation("创建tar.gz压缩文件"):
                with tarfile.open(output_filename, "w:gz") as tar:
                    for source_path in source_paths:
                        if os.path.isdir(source_path):
                            for root, dirs, files in os.walk(source_path):
                                for file in files:
                                    full_path = os.path.join(root, file)
                                    arcname = os.path.relpath(full_path, start=os.path.dirname(source_path))
                                    tar.add(full_path, arcname=arcname)
                        else:
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
    try:
        check_paths_exist([data_dir, plugins_dir])
        create_archive([data_dir, plugins_dir], output_file)
        if os.path.exists(temp_dir):
            shutil.rmtree(temp_dir)
        ensure_dir_exists(temp_dir)
        if not extract_archive(output_file, temp_dir):
            raise BackupError("解压备份文件失败")
        clean_files_from_directory(temp_dir, excluded_files)
        os.remove(output_file)
        temp_dir_contents = [os.path.join(temp_dir, item) for item in os.listdir(temp_dir)]
        modified_backup = output_file.replace(".tar.gz", "_modified.tar.gz")
        create_archive(temp_dir_contents, modified_backup)
        os.rename(modified_backup, output_file)
        final_backup_folder = os.path.join(os.path.dirname(temp_dir), "pagermaid_backup")
        if os.path.exists(final_backup_folder):
            shutil.rmtree(final_backup_folder)
        os.rename(temp_dir, final_backup_folder)
        return output_file, final_backup_folder
    except Exception as e:
        if os.path.exists(temp_dir):
            shutil.rmtree(temp_dir)
        if os.path.exists(output_file) and "modified" in output_file:
            os.remove(output_file)
        raise BackupError(f"备份处理失败: {str(e)}")


async def restore_backup(backup_file: str, target_dir: str) -> None:
    try:
        if not extract_archive(backup_file, target_dir):
            raise BackupError("解压备份文件失败")
        os.remove(backup_file)
        # 确保 pagermaid_backup 目录存在
        backup_folder = os.path.join(target_dir, "pagermaid_backup")
        if not os.path.isdir(backup_folder):
            os.makedirs(backup_folder, exist_ok=True)
            # 将解压出的所有内容移入该目录
            for item in os.listdir(target_dir):
                if item == "pagermaid_backup":
                    continue
                src = os.path.join(target_dir, item)
                dst = os.path.join(backup_folder, item)
                shutil.move(src, dst)
        # 复制 backup_folder 中的内容回根目录
        for item in os.listdir(backup_folder):
            src_path = os.path.join(backup_folder, item)
            dest_path = os.path.join(target_dir, item)
            if os.path.isdir(src_path):
                shutil.copytree(src_path, dest_path, dirs_exist_ok=True)
            else:
                shutil.copy2(src_path, dest_path)
        # 清理临时目录
        shutil.rmtree(backup_folder)
    except Exception as e:
        raise BackupError(f"恢复备份失败: {str(e)}")


@listener(outgoing=True, command="bf",
          description="将data和plugins文件夹打包成pagermaid_backup.tar.gz，删除备份包中的特定文件，然后重新打包并上传到收藏夹")
async def backup_and_clean(bot: Client, message: Message):
    try:
        await message.edit("正在创建备份...")
        program_dir = get_program_dir()
        data_dir = os.path.join(program_dir, "data")
        plugins_dir = os.path.join(program_dir, "plugins")
        backup_file = os.path.join(program_dir, DEFAULT_BACKUP_FILENAME)
        temp_dir = os.path.join(program_dir, TEMP_DIR_NAME)
        backup_file, _ = process_backup(
            data_dir,
            plugins_dir,
            backup_file,
            EXCLUDED_FILES,
            temp_dir
        )
        await message.edit("备份创建完成，正在上传到收藏夹...")
        await bot.send_document("me", backup_file, force_document=True)
        await message.edit("备份完成并已上传到收藏夹")
    except Exception as e:
        error_message = f"备份失败: {str(e)}"
        await message.edit(error_message)


@listener(outgoing=True, command="hf",
          description="释放pagermaid_backup文件夹到程序根目录，并删除原pagermaid_backup文件夹")
async def release_backup_folder(message: Message):
    reply = message.reply_to_message
    program_dir = get_program_dir()
    local_backup = os.path.join(program_dir, "pagermaid_backup")
    # 回复 .tar.gz 文件时恢复备份
    if reply and hasattr(reply, 'document') and reply.document and ".tar.gz" in reply.document.file_name:
        try:
            await message.edit("下载中...")
            backup_file = await reply.download()
            await message.edit("解压中...")
            await restore_backup(backup_file, program_dir)
            await message.edit("备份已恢复，请 `,restart`")
        except Exception as e:
            await message.edit(f"恢复失败: {e}")
        return
    # 如果存在本地备份文件夹，则释放它
    if os.path.isdir(local_backup):
        try:
            await message.edit("正在释放本地备份...")
            for item in os.listdir(local_backup):
                src_path = os.path.join(local_backup, item)
                dest_path = os.path.join(program_dir, item)
                if os.path.isdir(src_path):
                    shutil.copytree(src_path, dest_path, dirs_exist_ok=True)
                else:
                    shutil.copy2(src_path, dest_path)
            shutil.rmtree(local_backup)
            await message.edit("本地备份释放完成，请 `,restart`")
        except Exception as e:
            await message.edit(f"释放失败: {e}")
    else:
        await message.edit("请回复一个 `.tar.gz` 备份文件以进行恢复。")


@listener(
    command="transfer",
    description="上传 / 下载文件",
    parameters="upload [filepath] 或 download [filepath]",
)
async def transfer(bot: Client, message: Message):
    params = message.parameter
    if len(params) < 2:
        message: Message = await message.edit(
            "参数缺失，请使用 `upload [filepath (包括扩展名)]` 或 `download [filepath (包括扩展名)]`"
        )
        await message.delay_delete(3)
        return
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
