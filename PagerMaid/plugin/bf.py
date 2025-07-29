import os
import sys
import tarfile
import shutil
import subprocess
import zipfile
from pathlib import Path
from os.path import exists, isfile
from traceback import format_exc
from pagermaid.config import Config
from pagermaid.listener import listener
from pagermaid.enums import Client, Message
from pagermaid.utils import lang
from pagermaid.utils.bot_utils import upload_attachment

pgm_backup_zip_name = "pagermaid_backup.tar.gz"

def get_program_dir():
    try:
        result = subprocess.run(['pwd'], capture_output=True, text=True, check=True)
        return result.stdout.strip()
    except subprocess.CalledProcessError as e:
        raise RuntimeError(f"获取程序目录失败: {e}")

def create_tar_gz(source_dirs, output_filename):
    # 确保输出文件的父目录存在
    os.makedirs(os.path.dirname(output_filename), exist_ok=True)
    with tarfile.open(output_filename, "w:gz") as tar:
        for source_dir in source_dirs:
            if os.path.exists(source_dir):
                tar.add(source_dir, arcname=os.path.basename(source_dir))
            else:
                raise FileNotFoundError(f"{source_dir} 不存在")

def delete_specific_files_from_backup(backup_file, temp_dir, files_to_delete):
    # 确保临时目录存在
    os.makedirs(temp_dir, exist_ok=True)
    with tarfile.open(backup_file, "r:gz") as tar:
        tar.extractall(path=temp_dir)

    for root, dirs, files in os.walk(temp_dir):
        for file_name in files:
            if file_name in files_to_delete:
                file_path = os.path.join(root, file_name)
                os.remove(file_path)

    new_backup_file = backup_file.replace(".tar.gz", "_modified.tar.gz")
    # 确保新备份文件的父目录存在
    os.makedirs(os.path.dirname(new_backup_file), exist_ok=True)
    with tarfile.open(new_backup_file, "w:gz") as tar:
        tar.add(temp_dir, arcname="pagermaid_backup")

    return new_backup_file

async def make_zip(source_dir, output_filename):
    # 确保输出文件的父目录存在
    os.makedirs(os.path.dirname(output_filename), exist_ok=True)
    zipf = zipfile.ZipFile(output_filename, "w")
    pre_len = len(os.path.dirname(source_dir))
    for parent, dirnames, filenames in os.walk(source_dir):
        for filename in filenames:
            pathfile = os.path.join(parent, filename)
            arcname = pathfile[pre_len:].strip(os.path.sep)
            zipf.write(pathfile, arcname)
    zipf.close()

def make_tar_gz(output_filename, source_dirs: list):
    # 确保输出文件的父目录存在
    os.makedirs(os.path.dirname(output_filename), exist_ok=True)
    with tarfile.open(output_filename, "w:gz") as tar:
        for i in source_dirs:
            tar.add(i, arcname=os.path.basename(i))

def un_tar_gz(filename, dirs):
    try:
        # 确保目标目录存在
        os.makedirs(dirs, exist_ok=True)
        t = tarfile.open(filename, "r:gz")
        t.extractall(path=dirs)
        return True
    except Exception as e:
        print(e, format_exc())
        return False

@listener(outgoing=True, command="bf",
          description="将data和plugins文件夹打包成pagermaid_backup.tar.gz，删除备份包中的特定文件，然后重新打包并上传到收藏夹")
async def backup_and_clean(bot: Client, message: Message):
    try:
        program_dir = get_program_dir()

        data_dir = os.path.join(program_dir, "data")
        plugins_dir = os.path.join(program_dir, "plugins")
        final_backup = os.path.join(program_dir, "pagermaid_backup.tar.gz")
        temp_dir = os.path.join(program_dir, "temp_backup")
        files_to_delete = ["pagermaid.session-journal", "pagermaid.session"]

        # 确保data和plugins目录存在，如果不存在则创建
        os.makedirs(data_dir, exist_ok=True)
        os.makedirs(plugins_dir, exist_ok=True)

        await message.edit("正在创建备份...")
        create_tar_gz([data_dir, plugins_dir], final_backup)

        if not os.path.exists(temp_dir):
            os.makedirs(temp_dir)

        modified_backup = delete_specific_files_from_backup(final_backup, temp_dir, files_to_delete)

        os.remove(final_backup)

        os.rename(modified_backup, final_backup)

        final_backup_folder = os.path.join(program_dir, "pagermaid_backup")
        if os.path.exists(final_backup_folder):
            shutil.rmtree(final_backup_folder)
        # 确保目标目录存在，再进行重命名操作
        os.makedirs(os.path.dirname(final_backup_folder), exist_ok=True)
        os.rename(temp_dir, final_backup_folder)

        await message.edit("备份创建完成，正在上传到收藏夹...")
        await bot.send_document("me", final_backup, force_document=True)
        await message.edit("备份完成并已上传到收藏夹")
        
    except Exception as e:
        error_message = f"备份失败: {str(e)}"
        await message.edit(error_message)

@listener(outgoing=True, command="hf",
          description="释放pagermaid_backup文件夹到程序根目录，并删除原pagermaid_backup文件夹")
async def release_backup_folder(message: Message):
    reply = message.reply_to_message

    if not reply or not reply.document or ".tar.gz" not in reply.document.file_name:
        return await message.edit("请回复一个.tar.gz文件以进行恢复。")

    try:
        await message.edit("下载中...")
        # 确保下载路径的父目录存在
        download_path = os.path.join(get_program_dir(), reply.document.file_name)
        os.makedirs(os.path.dirname(download_path), exist_ok=True)
        pgm_backup_zip_name = await reply.download(file_name=download_path)  # 下载文件

        await message.edit("解压中...")
        program_dir = get_program_dir()

        # 解压到程序目录
        if not un_tar_gz(pgm_backup_zip_name, program_dir):
            os.remove(pgm_backup_zip_name)
            return await message.edit("解压文件失败。")

        os.remove(pgm_backup_zip_name)  # 删除压缩包

        final_backup_folder = os.path.join(program_dir, "pagermaid_backup")
        if not os.path.exists(final_backup_folder):
            raise FileNotFoundError(f"{final_backup_folder} 文件夹不存在")

        # 释放文件夹到根目录
        for item in os.listdir(final_backup_folder):
            src_path = os.path.join(final_backup_folder, item)
            dest_path = os.path.join(program_dir, item)
            if os.path.isdir(src_path):
                # 确保目标目录存在
                os.makedirs(dest_path, exist_ok=True)
                shutil.copytree(src_path, dest_path, dirs_exist_ok=True)
            else:
                # 确保目标文件的父目录存在
                os.makedirs(os.path.dirname(dest_path), exist_ok=True)
                shutil.copy2(src_path, dest_path)

        # 删除原pagermaid_backup文件夹
        shutil.rmtree(final_backup_folder)

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
    params = message.parameter
    if len(params) < 2:
        message: Message = await message.edit(
            "参数缺失，请使用 `upload [filepath (包括扩展名)]` 或 `download [filepath (包括扩展名)]`"
        )
        await message.delay_delete(3)
        return
    params[1] = " ".join(params[1:])
    file_list = params[1].split("\n")
    chat_id = message.chat.id
    if params[0] == "upload":
        index = 1
        for file_path in file_list:
            message: Message = await message.edit(f"正在上传第 {index} 个文件")
            if exists(file_path):
                if isfile(file_path):
                    await bot.send_document(chat_id, file_path, force_document=True)
                else:
                    token = file_path.split("/")[-1]
                    # 确保临时文件的父目录存在
                    temp_zip_path = f"/tmp/{token}.zip"
                    os.makedirs(os.path.dirname(temp_zip_path), exist_ok=True)
                    await make_zip(file_path, temp_zip_path)
                    await bot.send_document(
                        chat_id, temp_zip_path, force_document=True
                    )
                    os.remove(temp_zip_path)
            index += 1
        message: Message = await message.edit("上传完毕")
    elif params[0] == "download":
        if reply := message.reply_to_message:
            file_path = Path(file_list[0])
            if exists(file_path):
                message: Message = await message.edit("路径已存在文件")
            else:
                message: Message = await message.edit("下载中。。。")
                try:
                    # 确保下载路径的父目录存在
                    os.makedirs(os.path.dirname(file_path), exist_ok=True)
                    _file = await reply.download(file_name=file_list[0])
                except Exception:
                    await message.edit("无法下载此类型的文件。")
                    return
                message: Message = await message.edit(f"保存成功, 保存路径 `{file_list[0]}`")
        else:
            message: Message = await message.edit("未回复消息或回复消息中不包含文件")
    else:
        message: Message = await message.edit(
            "未知命令，请使用 `upload [filepath]` 或 `download [filepath]`"
        )
    await message.delay_delete(3)


