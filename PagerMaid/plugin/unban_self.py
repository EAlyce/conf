from typing import List, Optional

from pyrogram.enums import ChatMembersFilter
from pyrogram.errors import (
    ChatAdminRequired,
    FloodWait,
    PeerIdInvalid,
    UserAdminInvalid,
)
from pyrogram.types import ChatMember

from pagermaid.dependence import add_delete_message_job
from pagermaid.listener import listener
from pagermaid.enums import Client, Message
from pagermaid.utils import lang
from pagermaid.utils.bot_utils import log


async def get_banned_members_by_user(client: Client, chat_id: int, user_id: int) -> List[ChatMember]:
    """获取指定用户封禁的所有成员
    
    Args:
        client: Pyrogram客户端
        chat_id: 群组ID
        user_id: 用户ID
        
    Returns:
        被该用户封禁的成员列表
    """
    banned_by_user = []
    
    try:
        async for member in client.get_chat_members(
            chat_id,
            filter=ChatMembersFilter.BANNED
        ):
            # 检查是否由指定用户封禁
            if (
                member.restricted_by 
                and member.restricted_by.id == user_id 
                and member.user
            ):
                banned_by_user.append(member)
    except Exception as e:
        await log(f"unban_self - 获取封禁列表时出错: {e}")
        
    return banned_by_user


async def unban_member_safe(client: Client, chat_id: int, user_id: int) -> bool:
    """安全地解除用户封禁
    
    Args:
        client: Pyrogram客户端
        chat_id: 群组ID
        user_id: 用户ID
        
    Returns:
        是否成功解除封禁
    """
    try:
        await client.unban_chat_member(chat_id, user_id)
        return True
    except ChatAdminRequired:
        await log(f"unban_self - 解封用户 {user_id} 失败: 权限不足")
        return False
    except UserAdminInvalid:
        await log(f"unban_self - 解封用户 {user_id} 失败: 用户是管理员")
        return False
    except PeerIdInvalid:
        await log(f"unban_self - 解封用户 {user_id} 失败: 无效的用户ID")
        return False
    except FloodWait as e:
        await log(f"unban_self - 解封用户 {user_id} 失败: 请求过于频繁，需等待 {e.value} 秒")
        return False
    except Exception as e:
        await log(f"unban_self - 解封用户 {user_id} 时出现未知错误: {e}")
        return False


@listener(
    command="unban_self",
    description="一键解除自己封禁的所有用户",
    need_admin=True,
    groups_only=True,
)
async def unban_self(client: Client, message: Message):
    """解除当前用户封禁的所有用户
    
    该命令会:
    1. 获取群组中所有被封禁的用户
    2. 筛选出由当前用户封禁的用户
    3. 逐一解除这些用户的封禁
    4. 提供详细的操作反馈
    """
    chat_id = message.chat.id
    user_id = message.from_user.id
    
    # 更新消息状态
    await message.edit("🔍 正在查找您封禁的用户...")
    
    # 获取被当前用户封禁的成员列表
    banned_members = await get_banned_members_by_user(client, chat_id, user_id)
    
    if not banned_members:
        await message.edit("✅ 没有找到您封禁的用户")
        return add_delete_message_job(message, 10)
    
    # 开始解封操作
    total_count = len(banned_members)
    success_count = 0
    failed_users = []
    
    await message.edit(f"🔄 找到 {total_count} 个被您封禁的用户，开始解封...")
    
    for i, member in enumerate(banned_members, 1):
        # 更新进度
        if total_count > 5:  # 只有在用户较多时才显示进度
            await message.edit(f"🔄 解封进度: {i}/{total_count}")
        
        # 尝试解封用户
        if await unban_member_safe(client, chat_id, member.user.id):
            success_count += 1
        else:
            failed_users.append(member.user)
    
    # 生成结果消息
    if success_count == total_count:
        result_text = f"✅ 成功解封 {success_count} 个用户"
    elif success_count > 0:
        result_text = f"⚠️ 成功解封 {success_count}/{total_count} 个用户"
        if failed_users:
            failed_names = [user.first_name or f"用户{user.id}" for user in failed_users[:3]]
            if len(failed_users) > 3:
                failed_names.append(f"等{len(failed_users)}人")
            result_text += f"\n失败用户: {', '.join(failed_names)}"
    else:
        result_text = f"❌ 解封失败，共 {total_count} 个用户"
    
    await message.edit(result_text)
    
    # 记录详细日志
    log_message = (
        f"unban_self 操作完成\n"
        f"执行用户: {message.from_user.mention}\n"
        f"群组: {message.chat.title}\n"
        f"总数: {total_count}, 成功: {success_count}, 失败: {len(failed_users)}"
    )
    await log(log_message)
    
    # 延迟删除消息
    add_delete_message_job(message, 15)
