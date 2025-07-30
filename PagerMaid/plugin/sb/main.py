import contextlib
from asyncio import sleep
from typing import Optional, Tuple, List, Union

from pyrogram.enums import ChatType
from pyrogram.errors import (
    ChatAdminRequired,
    FloodWait,
    PeerIdInvalid,
    UserAdminInvalid,
    UsernameInvalid,
)
from pyrogram.types import Chat, User

from pagermaid.dependence import add_delete_message_job
from pagermaid.listener import listener
from pagermaid.services import bot
from pagermaid.enums import Message
from pagermaid.utils import lang
from pagermaid.utils.bot_utils import log


def mention_group(chat: Chat) -> str:
    """生成群组提及链接
    
    Args:
        chat: 群组对象
        
    Returns:
        格式化的群组链接或名称
    """
    return (
        f'<a href="https://t.me/{chat.username}">{chat.title}</a>'
        if chat.username
        else f"<code>{chat.title}</code>"
    )


async def ban_one(chat: Chat, uid: Union[int, str]) -> bool:
    """封禁单个用户
    
    Args:
        chat: 群组对象
        uid: 用户ID
        
    Returns:
        是否成功封禁
    """
    try:
        await bot.ban_chat_member(chat.id, uid)
        return True
    except Exception:
        return False


async def delete_all_messages(chat: Chat, uid: Union[int, str]) -> bool:
    """删除用户所有消息
    
    Args:
        chat: 群组对象
        uid: 用户ID
        
    Returns:
        是否成功删除
    """
    try:
        await bot.delete_user_history(chat.id, uid)
        return True
    except Exception:
        return False


async def check_uid(chat: Chat, uid: str) -> Tuple[Union[int, str], bool]:
    """检查并验证用户ID
    
    Args:
        chat: 群组对象
        uid: 用户ID字符串
        
    Returns:
        (处理后的uid, 是否为频道)
    """
    channel = False
    
    # 尝试转换为整数
    with contextlib.suppress(ValueError):
        uid = int(uid)
        if uid < 0:
            channel = True
    
    try:
        await bot.get_chat_member(chat.id, uid)
    except ChatAdminRequired:
        # 如果没有管理员权限，尝试获取聊天信息
        with contextlib.suppress(PeerIdInvalid):
            target_chat = await bot.get_chat(uid)
            uid = target_chat.id
            if target_chat.type in [ChatType.CHANNEL, ChatType.SUPERGROUP, ChatType.GROUP]:
                channel = True
    
    return uid, channel


async def get_uid(chat: Chat, message: Message) -> Tuple[Optional[Union[int, str]], bool, bool, Optional[User]]:
    """从消息中获取目标用户信息
    
    Args:
        chat: 群组对象
        message: 消息对象
        
    Returns:
        (用户ID, 是否为频道, 是否删除所有消息, 发送者对象)
    """
    uid = None
    channel = False
    delete_all = True
    sender = None
    
    # 优先处理回复消息
    if reply := message.reply_to_message:
        if sender := reply.from_user:
            uid = sender.id
        elif sender := reply.sender_chat:
            uid = sender.id
            channel = True
        
        # 如果有额外参数，不删除所有消息
        if message.arguments:
            delete_all = False
    
    # 处理命令参数
    elif len(message.parameter) == 2:
        uid, channel = await check_uid(chat, message.parameter[0])
        delete_all = False
    elif len(message.parameter) == 1:
        uid, channel = await check_uid(chat, message.parameter[0])
    
    return uid, channel, delete_all, sender


async def process_single_group(group_chat: Chat, uid: Union[int, str], delete_all: bool) -> bool:
    """处理单个群组的封禁操作
    
    Args:
        group_chat: 群组对象
        uid: 用户ID
        delete_all: 是否删除所有消息
        
    Returns:
        是否成功处理
    """
    try:
        # 尝试封禁用户
        ban_success = await ban_one(group_chat, uid)
        if not ban_success:
            return False
            
        # 如果需要删除消息
        if delete_all:
            await delete_all_messages(group_chat, uid)
            
        return True
        
    except ChatAdminRequired:
        return False
    except UserAdminInvalid:
        return False
    except FloodWait as e:
        # 处理频率限制
        await sleep(e.value)
        try:
            ban_success = await ban_one(group_chat, uid)
            if ban_success and delete_all:
                await delete_all_messages(group_chat, uid)
            return ban_success
        except Exception:
            return False
    except Exception:
        return False


@listener(
    command="sb",
    description=lang("sb_des"),
    need_admin=True,
    groups_only=True,
    parameters="[reply|id|username> <do_not_del_all]",
)
async def super_ban(message: Message):
    """超级封禁命令处理函数
    
    支持封禁用户并在所有共同群组中执行相同操作
    """
    chat = message.chat
    
    # 获取目标用户信息
    try:
        uid, channel, delete_all, sender = await get_uid(chat, message)
        
        # 验证用户ID有效性
        if not uid:
            raise ValueError("无效的用户ID")
        if channel and uid == chat.id:
            raise ValueError("不能封禁当前群组")
            
    except (ValueError, PeerIdInvalid, UsernameInvalid) as e:
        await message.edit(f"{lang('arg_error')} - {str(e)}")
        return add_delete_message_job(message, 30)
    except FloodWait as e:
        await message.edit(f"请求过于频繁，请等待 {e.value} 秒")
        return add_delete_message_job(message, 30)
    except Exception as e:
        await message.edit(f"获取用户信息时出现错误：{e}")
        return add_delete_message_job(message, 30)
    # 处理频道封禁
    if channel:
        ban_success = await ban_one(chat, uid)
        if not ban_success:
            await message.edit(lang("sb_no_per"))
            return add_delete_message_job(message, 10)
        
        await message.edit(lang("sb_channel"))
        await log(f"频道封禁成功 - uid: `{uid}` 在群组: {mention_group(chat)}")
        return add_delete_message_job(message, 10)
    # 获取共同群组列表
    try:
        common = await bot.get_common_chats(uid)
    except PeerIdInvalid:
        # 如果无法获取共同群组，只在当前群组操作
        common = [chat]
    except Exception as e:
        await message.edit(f"获取共同群组时出错：{e}")
        return add_delete_message_job(message, 30)
    count, groups = 0, []
    
    # 批量处理所有群组
    for group_chat in common:
        success = await process_single_group(group_chat, uid, delete_all)
        if success:
            count += 1
            groups.append(mention_group(group_chat))
    # 获取用户信息用于显示
    if not sender:
        try:
            sender = await bot.get_users(uid)
        except Exception:
            sender = None
    
    # 生成结果消息
    if count == 0:
        text = f'{lang("sb_no")} {sender.mention if sender else f"用户 {uid}"}'
    else:
        text = f'{lang("sb_per")} {count} {lang("sb_in")} {sender.mention if sender else f"用户 {uid}"}'
    
    await message.edit(text)
    
    # 记录详细日志
    groups_text = f'\n{lang("sb_pro")}\n' + "\n".join(groups) if groups else ""
    log_message = f"{text}\nuid: `{uid}`\n删除消息: {'是' if delete_all else '否'}{groups_text}"
    await log(log_message)
    
    add_delete_message_job(message, 1)
