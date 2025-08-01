""" PagerMaid module for channel help. """

import contextlib
import datetime
import json
import re
from asyncio import sleep
from random import uniform
from typing import Any, List, Literal, Optional, Dict

import pytz
from pyrogram.enums import ChatType
from pyrogram.errors import FloodWait, UserIsBlocked, ChatWriteForbidden, UserDeactivated
from pyrogram.types import Chat, User, InlineKeyboardButton, InlineKeyboardMarkup

from pagermaid.config import Config
from pagermaid.enums import Client, Message
from pagermaid.enums.command import CommandHandler
from pagermaid.listener import listener
from pagermaid.services import bot, scheduler, sqlite
from pagermaid.utils import lang, logs
from pagermaid.utils.bot_utils import log

WHITELIST = [-1001441461877]
AVAILABLE_OPTIONS_TYPE = Literal["silent", "text", "all", "photo", "document", "video", "sticker", "animation", "voice", "audio"]
AVAILABLE_OPTIONS = {"silent", "text", "all", "photo", "document", "video", "sticker", "animation", "voice", "audio"}
HELP_TEXT = """📢 智能转发助手使用说明

🔧 基础命令：
- set [源] [目标] [选项...] - 自动转发消息
- del [源] - 删除转发规则
- backup [源] [目标] [选项...] - 备份历史消息
- list - 显示当前转发规则
- stats - 查看转发统计
- pause [源] - 暂停转发
- resume [源] - 恢复转发
- filter [源] add [关键词] - 添加过滤关键词
- filter [源] del [关键词] - 删除过滤关键词
- filter [源] list - 查看过滤列表
- 支持序号操作 例如 shift del 1,2,3...
🎯 支持的目标类型：
- 频道/群组 - @channel_username 或 -1001234567890
- 个人用户 - @username 或 user_id
- 机器人 - @bot_username 或 bot_id
- 当前对话 - 使用 "me" 或 "here"

📝 消息类型选项：
- silent - 禁用通知（仅对频道/群组有效）
- text - 仅文字消息
- photo - 仅图片消息
- document - 仅文件消息
- video - 仅视频消息
- sticker - 仅贴纸消息
- animation - 仅动图消息
- voice - 仅语音消息
- audio - 仅音频消息
- all - 所有类型消息（默认）

💡 使用示例：
shift set @source_channel @target_user silent photo
shift set -1001234567890 me text
shift set @news_channel @my_bot all
shift filter -1001234567890 add 广告 垃圾

⚠️ 注意事项：
- 转发给个人/机器人时，silent 选项无效
- 确保目标用户/机器人未屏蔽您的账号
- 转发给个人时请遵守隐私和相关法规"""


def try_cast_or_fallback(val: Any, t: type) -> Any:
    try:
        return t(val)
    except:
        return val


def check_source_available(chat: Chat):
    """检查源聊天是否可用"""
    assert (
        chat.type
        in [
            ChatType.CHANNEL,
            ChatType.GROUP,
            ChatType.SUPERGROUP,
        ]
        and not chat.has_protected_content
    )


def check_target_available(chat_or_user):
    """检查目标是否可用（更宽松的检查）"""
    if isinstance(chat_or_user, User):
        return True  # 用户总是可以作为目标
    elif isinstance(chat_or_user, Chat):
        # 几乎所有聊天类型都可以作为目标
        return chat_or_user.type in [
            ChatType.CHANNEL,
            ChatType.GROUP,
            ChatType.SUPERGROUP,
            ChatType.BOT,
            ChatType.PRIVATE,
        ]
    return False


def is_circular_forward(source_id: int, target_id: int) -> (bool, str):
    """检查添加转发规则是否会产生循环。返回 (is_circular, error_message)。"""
    # 直接循环检查：源和目标相同
    if source_id == target_id:
        return True, f"不能设置自己到自己的转发规则"
    
    # 直接循环检查：目标已经转发到源
    existing_rule_str = sqlite.get(f"shift.{target_id}")
    if existing_rule_str:
        try:
            existing_rule = json.loads(existing_rule_str)
            if int(existing_rule.get('target_id', -1)) == source_id:
                return True, f"检测到直接循环：{target_id} 已经转发到 {source_id}"
        except (json.JSONDecodeError, ValueError, TypeError):
            pass  # 如果数据损坏，则忽略
    
    # 间接循环检查：沿着转发链追踪
    path = {source_id}
    current_id = target_id
    chain = [source_id, target_id]

    # 间接循环检查：沿着转发链追踪
    while True:
        # 从数据库中获取下一个转发目标
        # 我们只关心是否存在转发，不关心具体配置
        value = sqlite.get(f"shift.{current_id}")
        if not value:
            # 链条中断，没有循环
            return False, ""

        # 假设 value 是一个 JSON 字符串，包含 target_id
        try:
            rule_data = json.loads(value)
            next_target_id = int(rule_data.get('target_id', -1))
            if next_target_id == -1:
                return False, ""
        except (json.JSONDecodeError, ValueError, TypeError):
            # 如果数据损坏或格式不正确，则认为链中断
            return False, ""

        # 检查是否形成循环
        if next_target_id in path:
            chain.append(next_target_id)
            path_str = " -> ".join(map(str, chain))
            return True, f"检测到间接循环：{path_str}"

        # 安全退出：防止因意外数据导致的无限循环
        if len(path) > 50:  # 假设转发链深度不超过50
            return True, "转发链过长，可能存在循环"

        # 继续追踪
        path.add(next_target_id)
        chain.append(next_target_id)
        current_id = next_target_id


def get_display_name(chat_or_user) -> str:
    """获取聊天或用户的显示名称"""
    if isinstance(chat_or_user, User):
        name_parts = []
        if chat_or_user.first_name:
            name_parts.append(chat_or_user.first_name)
        if chat_or_user.last_name:
            name_parts.append(chat_or_user.last_name)
        display_name = " ".join(name_parts) or f"User {chat_or_user.id}"
        
        if chat_or_user.username:
            return f"{display_name} (@{chat_or_user.username})"
        else:
            return f"{display_name} ({chat_or_user.id})"
    
    elif isinstance(chat_or_user, Chat):
        if chat_or_user.title:
            base_name = chat_or_user.title
        elif chat_or_user.first_name:
            name_parts = [chat_or_user.first_name]
            if chat_or_user.last_name:
                name_parts.append(chat_or_user.last_name)
            base_name = " ".join(name_parts)
        else:
            base_name = f"{chat_or_user.type.value.title()} {chat_or_user.id}"
        
        if chat_or_user.username:
            return f"{base_name} (@{chat_or_user.username})"
        else:
            return f"{base_name} ({chat_or_user.id})"
    
    return str(chat_or_user)


def get_target_type_emoji(chat_or_user) -> str:
    """获取目标类型对应的 emoji"""
    if isinstance(chat_or_user, User):
        return "👤"  # 个人用户
    elif isinstance(chat_or_user, Chat):
        if chat_or_user.type == ChatType.BOT:
            return "🤖"  # 机器人
        elif chat_or_user.type == ChatType.CHANNEL:
            return "📢"  # 频道
        elif chat_or_user.type in [ChatType.GROUP, ChatType.SUPERGROUP]:
            return "👥"  # 群组
        elif chat_or_user.type == ChatType.PRIVATE:
            return "💬"  # 私聊
    return "📝"  # 默认


def update_stats(source_id: int, target_id: int, message_type: str = "unknown"):
    """更新转发统计"""
    today = datetime.datetime.now().strftime("%Y-%m-%d")
    stats_key = f"shift.stats.{source_id}.{today}"
    current_stats = sqlite.get(stats_key, {})
    
    if isinstance(current_stats, str):
        try:
            current_stats = json.loads(current_stats)
        except:
            current_stats = {}
    
    current_stats["total"] = current_stats.get("total", 0) + 1
    current_stats["target"] = target_id
    current_stats[message_type] = current_stats.get(message_type, 0) + 1
    
    sqlite[stats_key] = json.dumps(current_stats)


def is_message_filtered(message: Message, source_id: int) -> bool:
    """检查消息是否被过滤"""
    filter_key = f"shift.filter.{source_id}"
    keywords = sqlite.get(filter_key, [])
    
    if not keywords or not message.text:
        return False
    
    text_lower = message.text.lower()
    return any(keyword.lower() in text_lower for keyword in keywords)


async def resolve_target(client: Client, target_input: str, current_chat_id: int):
    """解析目标输入，支持多种格式"""
    # 处理特殊关键词
    if target_input.lower() in ["me", "here", "this"]:
        return await client.get_chat(current_chat_id)
    
    # 尝试作为数字ID解析
    try:
        target_id = int(target_input)
        return await client.get_chat(target_id)
    except ValueError:
        pass
    except Exception as e:
        # 如果是用户ID但get_chat失败，尝试get_users
        try:
            if target_input.isdigit() or (target_input.startswith('-') and target_input[1:].isdigit()):
                user = await client.get_users(int(target_input))
                return user
        except:
            pass
        raise e
    
    # 尝试作为用户名解析
    if target_input.startswith('@'):
        target_input = target_input[1:]
    
    try:
        # 先尝试作为聊天获取
        return await client.get_chat(target_input)
    except:
        try:
            # 如果失败，尝试作为用户获取
            user = await client.get_users(target_input)
            return user
        except:
            raise Exception(f"无法找到目标：{target_input}")


@listener(
    command="shift",
    description="智能转发助手",
    parameters=HELP_TEXT,
)
async def shift_func(message: Message):
    keyboard = InlineKeyboardMarkup([
        [
            InlineKeyboardButton("📝 设置转发", callback_data="shift_help_set"),
            InlineKeyboardButton("📊 查看统计", callback_data="shift_help_stats")
        ],
        [
            InlineKeyboardButton("📋 转发列表", callback_data="shift_help_list"),
            InlineKeyboardButton("🔧 过滤设置", callback_data="shift_help_filter")
        ]
    ])
    await message.edit(HELP_TEXT, reply_markup=keyboard)


shift_func: "CommandHandler"


@shift_func.sub_command(command="set")
async def shift_func_set(client: Client, message: Message):
    if len(message.parameter) < 3:
        return await message.edit(f"❌ {lang('error_prefix')}{lang('arg_error')}\n\n💡 使用方法：shift set [源] [目标] [选项...]\n\n🎯 目标可以是：频道、群组、个人用户、机器人或 'me'")
    
    options = set(message.parameter[3:] if len(message.parameter) > 3 else ())
    if set(options).difference(AVAILABLE_OPTIONS):
        invalid_options = set(options).difference(AVAILABLE_OPTIONS)
        return await message.edit(f"❌ 无法识别的选项：{', '.join(invalid_options)}\n\n✅ 可用选项：{', '.join(AVAILABLE_OPTIONS)}")
    
    # 检查来源
    try:
        source = await client.get_chat(try_cast_or_fallback(message.parameter[1], int))
        assert isinstance(source, Chat)
        check_source_available(source)
    except Exception as e:
        return await message.edit(f"❌ 无法识别的来源对话：{message.parameter[1]}\n\n💡 请确保频道/群组存在且机器人有访问权限\n\n🔍 错误详情：{str(e)}")
    
    if source.id in WHITELIST:
        return await message.edit("❌ 此对话位于白名单中，无法设置转发")
    
    # 检查目标（使用新的解析函数）
    try:
        target = await resolve_target(client, message.parameter[2], message.chat.id)
        check_target_available(target)
    except Exception as e:
        return await message.edit(f"❌ 无法识别的目标：{message.parameter[2]}\n\n💡 目标可以是：\n• 频道/群组：@channel 或 -1001234567890\n• 个人用户：@username 或 user_id\n• 机器人：@bot_username\n• 当前对话：me\n\n🔍 错误详情：{str(e)}")
    
    target_id = target.id
    if target_id in WHITELIST:
        return await message.edit("❌ 此对话位于白名单中，无法设置为目标")

    # 检查转发循环
    is_circular, error_msg = is_circular_forward(source.id, target_id)
    if is_circular:
        return await message.edit(f"❌ 操作被禁止：{error_msg}")
    
    # 检查silent选项的有效性
    if "silent" in options and isinstance(target, User):
        options.discard("silent")
        await message.edit("⚠️ 注意：转发给个人用户时，silent 选项无效，已自动移除", reply_markup=None)
        await sleep(2)
    
    # 保存配置
    rule_data = {
        "target_id": target_id,
        "options": list(options),
        "target_type": "user" if isinstance(target, User) else "chat",
        "paused": False,
        "created_at": datetime.datetime.now(pytz.timezone(Config.TIME_ZONE)).isoformat()
    }
    sqlite[f"shift.{source.id}"] = json.dumps(rule_data)
    
    source_name = get_display_name(source)
    target_name = get_display_name(target)
    target_emoji = get_target_type_emoji(target)
    options_text = "、".join(options) if options else "all"
    
    success_msg = f"✅ 转发规则设置成功！\n\n📤 源：{get_target_type_emoji(source)} {source_name}\n📥 目标：{target_emoji} {target_name}\n⚙️ 选项：{options_text}"
    
    # 如果是转发给个人用户，添加提醒
    if isinstance(target, User):
        success_msg += "\n\n⚠️ 提醒：转发给个人用户时请确保：\n• 对方未屏蔽您的账号\n• 遵守相关隐私法规"
    
    await message.edit(success_msg)
    await log(f"已成功配置将对话 {source.id} 的新消息转发到 {target_id} ({type(target).__name__})")


@shift_func.sub_command(command="del")
async def shift_func_del(client: Client, message: Message):
    if len(message.parameter) < 2:
        return await message.edit("❌ 参数错误，请提供要删除的规则序号。\n\n💡 使用方法：`shift del 1,2,3`")

    indices_str = message.parameter[1]
    indices_to_process = []
    invalid_indices = []

    all_shifts = sorted([k for k in sqlite if k.startswith("shift.") and k.count('.') == 1])

    for i_str in indices_str.split(','):
        try:
            index = int(i_str.strip()) - 1
            if 0 <= index < len(all_shifts):
                indices_to_process.append(index)
            else:
                invalid_indices.append(i_str)
        except ValueError:
            invalid_indices.append(i_str)

    if not indices_to_process:
        return await message.edit(f"❌ 未提供有效序号。无效输入：{', '.join(invalid_indices)}")

    deleted_count = 0
    # 从大到小删除，避免索引变化导致错误
    for index in sorted(indices_to_process, reverse=True):
        try:
            key_to_del = all_shifts.pop(index)
            source_id_str = key_to_del.split('.')[1]
            
            # 1. 删除主规则键
            if key_to_del in sqlite:
                del sqlite[key_to_del]
                deleted_count += 1
            
            # 2. 删除相关的统计键
            stats_prefix = f"shift.stats.{source_id_str}"
            keys_to_remove = [k for k in sqlite if k.startswith(stats_prefix)]
            for k in keys_to_remove:
                with contextlib.suppress(KeyError):
                    del sqlite[k]
        except (IndexError, KeyError):
            pass  # 忽略已删除或无效的
    
    result_message = f"✅ 成功删除 {deleted_count} 条转发规则。"
    if invalid_indices:
        result_message += f"\n⚠️ 无效或越界的序号: {', '.join(invalid_indices)}。"
    
    await message.edit(result_message)


@shift_func.sub_command(command="backup")
async def shift_func_backup(client: Client, message: Message):
    if len(message.parameter) < 3:
        return await message.edit(f"❌ {lang('error_prefix')}{lang('arg_error')}\n\n💡 使用方法：shift backup [源] [目标] [选项...]")
    
    options = set(message.parameter[3:] if len(message.parameter) > 3 else ())
    if set(options).difference(AVAILABLE_OPTIONS):
        invalid_options = set(options).difference(AVAILABLE_OPTIONS)
        return await message.edit(f"❌ 无法识别的选项：{', '.join(invalid_options)}")
    
    # 检查来源
    try:
        source = await client.get_chat(try_cast_or_fallback(message.parameter[1], int))
        assert isinstance(source, Chat)
        check_source_available(source)
    except Exception:
        return await message.edit(f"❌ 无法识别的来源对话：{message.parameter[1]}")
    
    if source.id in WHITELIST:
        return await message.edit("❌ 此对话位于白名单中")
    
    # 检查目标
    try:
        target = await resolve_target(client, message.parameter[2], message.chat.id)
        check_target_available(target)
    except Exception as e:
        return await message.edit(f"❌ 无法识别的目标：{message.parameter[2]}\n\n🔍 错误详情：{str(e)}")
    
    if target.id in WHITELIST:
        return await message.edit("❌ 此对话位于白名单中")

    # 检查是否存在循环转发
    is_circular, error_msg = is_circular_forward(source.id, target.id)
    if is_circular:
        return await message.edit(f"❌ 操作被禁止：{error_msg}")
    
    source_name = get_display_name(source)
    target_name = get_display_name(target)
    target_emoji = get_target_type_emoji(target)
    
    # 开始备份
    await message.edit(f"🔄 开始备份...\n\n📤 源：{get_target_type_emoji(source)} {source_name}\n📥 目标：{target_emoji} {target_name}")
    
    count = 0
    error_count = 0
    
    async for msg in client.search_messages(source.id):  # type: ignore
        await sleep(uniform(0.5, 1.0))
        try:
            await loosely_forward(
                message,
                msg,
                target.id,
                list(options),
                disable_notification="silent" in options and isinstance(target, Chat),
                ignore_forwarded=True,  # 在备份时强制转发
                _chain_depth=0,  # 备份时重置链深度
            )
            count += 1
        except Exception as e:
            error_count += 1
            logs.debug(f"备份消息失败: {e}")
        
        # 每处理50条消息更新一次进度
        if (count + error_count) % 50 == 0:
            await message.edit(f"🔄 备份进行中...\n\n📤 源：{get_target_type_emoji(source)} {source_name}\n📥 目标：{target_emoji} {target_name}\n📊 已处理：{count + error_count} 条（成功：{count}，失败：{error_count}）")
    
    result_msg = f"✅ 备份完成！\n\n📤 源：{get_target_type_emoji(source)} {source_name}\n📥 目标：{target_emoji} {target_name}\n📊 总计：{count + error_count} 条消息\n✅ 成功：{count} 条"
    
    if error_count > 0:
        result_msg += f"\n❌ 失败：{error_count} 条"
        if isinstance(target, User):
            result_msg += "\n\n💡 部分失败可能因为用户隐私设置或账号状态"
    
    await message.edit(result_msg)


@shift_func.sub_command(command="list")
async def get_chat_display_name_and_info(client: Client, chat_id: int, chat_type: str = "chat", cache: Optional[Dict[int, Any]] = None) -> (str, Any):
    """获取聊天显示名称和信息对象，支持缓存。"""
    if cache is not None and chat_id in cache:
        chat_info = cache[chat_id]
    else:
        try:
            if chat_type == "user":
                chat_info = await client.get_users(chat_id)
            else:
                chat_info = await client.get_chat(chat_id)
            if cache is not None:
                cache[chat_id] = chat_info
        except Exception:
            chat_info = None
            if cache is not None:
                cache[chat_id] = None # 缓存失败结果，避免重复请求

    if chat_info:
        if hasattr(chat_info, 'username') and chat_info.username:
            display_name = f"@{chat_info.username}"
        elif hasattr(chat_info, 'title') and chat_info.title:
            display_name = chat_info.title
        elif hasattr(chat_info, 'first_name') and chat_info.first_name:
            name_parts = [chat_info.first_name]
            if hasattr(chat_info, 'last_name') and chat_info.last_name:
                name_parts.append(chat_info.last_name)
            display_name = " ".join(name_parts)
        else:
            display_name = str(chat_id)
    else:
        display_name = str(chat_id)
    
    return display_name, chat_info


@shift_func.sub_command(command="list")
async def shift_func_list(client: Client, message: Message):
    info_cache: Dict[int, Any] = {}
    from_ids = sorted([k for k in sqlite if k.startswith("shift.") and k.count('.') == 1])
    if not from_ids:
        return await message.edit("📭 当前没有配置任何转发规则")
    
    output = f"📋 转发规则列表（{len(from_ids)} 个）\n\n"
    
    for i, from_id in enumerate(from_ids, 1):
        source_id = from_id[6:]  # 移除 "shift." 前缀
        try:
            rule_data = json.loads(sqlite[from_id])
            target_id = rule_data["target_id"]
            options = rule_data.get("options", ["all"])
            created_str = rule_data.get("created_at", "")
            target_type = rule_data.get("target_type", "chat")
            is_paused = rule_data.get("paused", False)
        except (json.JSONDecodeError, KeyError, TypeError):
            # 跳过格式不正确或已损坏的规则，仍然输出简要信息
            logs.warning(f"[SHIFT] 无法解析规则: {from_id}")
            output += f"{i}. ⚠️ 规则数据损坏或非标准格式: {from_id}\n\n"
            continue
        
        status = "⏸️ 已暂停" if is_paused else "▶️ 运行中"

        source_display, _ = await get_chat_display_name_and_info(client, int(source_id), cache=info_cache)
        target_display, target_info = await get_chat_display_name_and_info(client, target_id, target_type, cache=info_cache)

        # 根据获取到的 target_info 设置 emoji
        if target_info:
            target_emoji = get_target_type_emoji(target_info)
        else:
            target_emoji = "📝"

        output += f"{i}. {status}\n"

        output += f"   📤 {source_display}\n"
        output += f"   📥 {target_emoji} {target_display}\n"
        output += f"   ⚙️ 选项：{', '.join(options)}\n"
        output += f"   🎯 类型：{'个人用户' if target_type == 'user' else '聊天'}\n"
        
        if created_str:
            try:
                created_dt = datetime.datetime.fromisoformat(created_str)
                output += f"   📅 创建：{created_dt.strftime('%Y-%m-%d %H:%M')}\n"
            except:
                pass
        output += "\n"
    
    await message.edit(output)


@shift_func.sub_command(command="stats")
async def shift_func_stats(message: Message):
    """查看转发统计"""
    stats_keys = [k for k in sqlite.keys() if k.startswith("shift.stats.")]
    
    if not stats_keys:
        return await message.edit("📊 暂无转发统计数据")
    
    # 按源频道分组统计
    channel_stats = {}
    for key in stats_keys:
        parts = key.split(".")
        if len(parts) >= 4:
            source_id = parts[2]
            date = parts[3]
            
            if source_id not in channel_stats:
                channel_stats[source_id] = {"total": 0, "dates": {}}
            
            try:
                daily_stats = json.loads(sqlite[key])
                channel_stats[source_id]["total"] += daily_stats.get("total", 0)
                channel_stats[source_id]["dates"][date] = daily_stats.get("total", 0)
                channel_stats[source_id]["target"] = daily_stats.get("target")
                channel_stats[source_id]["target_type"] = sqlite.get(f"shift.{source_id}.target_type", "chat")
            except:
                pass
    
    output = "📊 转发统计报告\n\n"
    
    for source_id, stats in channel_stats.items():
        target_type_text = "👤 个人用户" if stats.get("target_type") == "user" else "💬 聊天"
        
        output += f"📤 源：{format_id_link(source_id)}\n"
        output += f"📥 目标：{format_id_link(stats.get('target', '未知'))} ({target_type_text})\n"
        output += f"📈 总转发：{stats['total']} 条\n"
        
        # 显示最近7天的数据
        recent_dates = sorted(stats['dates'].keys())[-7:]
        if recent_dates:
            output += "📅 最近7天：\n"
            for date in recent_dates:
                output += f"      {date}: {stats['dates'][date]} 条\n"
        output += "\n"
    
    await message.edit(output)


@shift_func.sub_command(command="pause")
async def shift_func_pause(client: Client, message: Message):
    """暂停转发"""
    if len(message.parameter) < 2:
        return await message.edit("❌ 参数错误，请提供要暂停的规则序号。\n\n💡 使用方法：`shift pause 1,2,3`")

    indices_str = message.parameter[1]
    indices_to_process = []
    invalid_indices = []

    all_shifts = sorted([k for k in sqlite if k.startswith("shift.") and k.count('.') == 1])

    for i_str in indices_str.split(','):
        try:
            index = int(i_str.strip()) - 1
            if 0 <= index < len(all_shifts):
                indices_to_process.append(index)
            else:
                invalid_indices.append(i_str)
        except ValueError:
            invalid_indices.append(i_str)

    if not indices_to_process:
        return await message.edit(f"❌ 未提供有效序号。无效输入：{', '.join(invalid_indices)}")

    paused_count = 0
    for index in indices_to_process:
        try:
            key = all_shifts[index]
            source_id_str = key.split('.')[1]
            rule_str = sqlite.get(f"shift.{source_id_str}")
            if rule_str:
                try:
                    rule_data = json.loads(rule_str)
                    rule_data['paused'] = True
                    sqlite[f"shift.{source_id_str}"] = json.dumps(rule_data)
                    paused_count += 1
                except (json.JSONDecodeError, TypeError):
                    # 跳过损坏的规则
                    pass
        except (IndexError, KeyError):
            pass

    result_message = f"⏸️ 成功暂停 {paused_count} 条转发规则。"
    if invalid_indices:
        result_message += f"\n⚠️ 无效或越界的序号: {', '.join(invalid_indices)}。"

    await message.edit(result_message)


@shift_func.sub_command(command="resume")
async def shift_func_resume(client: Client, message: Message):
    """恢复转发"""
    if len(message.parameter) < 2:
        return await message.edit("❌ 参数错误，请提供要恢复的规则序号。\n\n💡 使用方法：`shift resume 1,2,3`")

    indices_str = message.parameter[1]
    indices_to_process = []
    invalid_indices = []

    all_shifts = sorted([k for k in sqlite if k.startswith("shift.") and k.count('.') == 1])

    for i_str in indices_str.split(','):
        try:
            index = int(i_str.strip()) - 1
            if 0 <= index < len(all_shifts):
                indices_to_process.append(index)
            else:
                invalid_indices.append(i_str)
        except ValueError:
            invalid_indices.append(i_str)

    if not indices_to_process:
        return await message.edit(f"❌ 未提供有效序号。无效输入：{', '.join(invalid_indices)}")

    resumed_count = 0
    for index in indices_to_process:
        try:
            key = all_shifts[index]
            rule_str = sqlite.get(key)
            if rule_str:
                try:
                    rule_data = json.loads(rule_str)
                    rule_data['paused'] = False
                    sqlite[key] = json.dumps(rule_data)
                    resumed_count += 1
                except (json.JSONDecodeError, TypeError):
                    # 跳过损坏的规则
                    pass
        except (IndexError, KeyError):
            pass

    result_message = f"▶️ 成功恢复 {resumed_count} 条转发规则。"
    if invalid_indices:
        result_message += f"\n⚠️ 无效或越界的序号: {', '.join(invalid_indices)}。"

    await message.edit(result_message)


@shift_func.sub_command(command="filter")
async def shift_func_filter(client: Client, message: Message):
    """管理过滤关键词"""
    if len(message.parameter) < 3:
        return await message.edit(
            "❌ 使用方法：\n"
            "`shift filter add/del [序号] [关键词]`\n"
            "`shift filter list [序号]`"
        )

    action = message.parameter[1]
    all_shifts = sorted([k for k in sqlite if k.startswith("shift.") and k.count('.') == 1])

    if action == "list":
        try:
            index = int(message.parameter[2]) - 1
            if not (0 <= index < len(all_shifts)):
                return await message.edit("❌ 无效的序号。")
            key = all_shifts[index]
            source_id = int(key.split('.')[1])
        except (ValueError, IndexError):
            return await message.edit("❌ 无效的序号。")

        rule_str = sqlite.get(key)
        if not rule_str:
            return await message.edit("❌ 规则数据不存在或已损坏。")
        try:
            rule_data = json.loads(rule_str)
            filters = rule_data.get("filters", [])
            if not filters:
                return await message.edit(f"🔍 规则 {index + 1} ({source_id}) 没有设置过滤关键词。")
            
            text = f"🔍 规则 {index + 1} ({source_id}) 的过滤关键词：\n"
            text += "\n".join([f"- `{f}`" for f in filters])
            return await message.edit(text)
        except (json.JSONDecodeError, TypeError):
            return await message.edit("❌ 规则数据损坏。")

    if action not in ["add", "del"]:
        return await message.edit("❌ 无效的操作，请使用 `add`, `del`, 或 `list`。")

    if len(message.parameter) < 4:
        return await message.edit(f"❌ 请提供要 {action} 的关键词。")

    indices_str = message.parameter[2]
    keywords = message.parameter[3:]
    keywords = message.parameter[3:]

    indices_to_process = []
    invalid_indices = []

    for i_str in indices_str.split(','):
        try:
            index = int(i_str.strip()) - 1
            if 0 <= index < len(all_shifts):
                indices_to_process.append(index)
            else:
                invalid_indices.append(i_str)
        except ValueError:
            invalid_indices.append(i_str)

    if not indices_to_process:
        return await message.edit(f"❌ 未提供有效序号。无效输入：{', '.join(invalid_indices)}")

    updated_count = 0
    for index in indices_to_process:
        try:
            key = all_shifts[index]
            rule_str = sqlite.get(key)
            if not rule_str:
                continue
            try:
                rule_data = json.loads(rule_str)
                current_filters = rule_data.get("filters", [])

                if action == "add":
                    for kw in keywords:
                        if kw not in current_filters:
                            current_filters.append(kw)
                elif action == "del":
                    current_filters = [f for f in current_filters if f not in keywords]
                
                rule_data["filters"] = current_filters
                sqlite[key] = json.dumps(rule_data)
                updated_count += 1
            except (json.JSONDecodeError, TypeError):
                pass # 跳过损坏的规则
        except (IndexError, KeyError):
            pass

    action_text = "添加" if action == "add" else "删除"
    result_message = f"✅ 成功为 {updated_count} 条规则 {action_text} 了关键词。"
    if invalid_indices:
        result_message += f"\n⚠️ 无效或越界的序号: {', '.join(invalid_indices)}。"

    await message.edit(result_message)


def format_id_link(chat_id):
    """格式化ID为链接"""
    chat_id_str = str(chat_id)
    if chat_id_str.startswith("-100"):
        short_id = chat_id_str[4:]
        return f"[{chat_id}](https://t.me/c/{short_id})"
    else:
        return str(chat_id)


@listener(is_plugin=True, incoming=True, ignore_edited=True, ignore_forwarded=False, from_self=True)
async def shift_channel_message(message: Message):
    """Event handler to auto forward channel messages."""
    source = message.chat.id
    rule_str = sqlite.get(f"shift.{source}")
    if not rule_str:
        return

    try:
        rule_data = json.loads(rule_str)
        target_id = int(rule_data["target_id"])
        is_paused = rule_data.get("paused", False)
        options = rule_data.get("options", ["all"])
        target_type = rule_data.get("target_type", "chat")
    except (json.JSONDecodeError, KeyError, TypeError) as e:
        logs.error(f"[SHIFT] 无法解析规则 {source}: {e}")
        return

    logs.debug(f"[SHIFT] 收到消息 - 频道: {source}, 消息ID: {message.id}, 目标: {target_id}, 暂停: {is_paused}")

    if is_paused:
        return
    
    if message.chat.has_protected_content:
        # 如果源频道开启了内容保护，自动删除规则
        del sqlite[f"shift.{source}"]
        return
    
    if is_message_filtered(message, source):
        return

    with contextlib.suppress(Exception):
        if message.media_group_id:
            add_or_replace_forward_group_media(
                target_id,
                source,
                message.id,
                message.media_group_id,
                options,
                disable_notification="silent" in options and target_type == "chat",
            )
            return
        
        logs.debug(f"[SHIFT] 开始转发 - 从 {source} 到 {target_id}")
        await loosely_forward(
            None,
            message,
            target_id,
            options,
            disable_notification="silent" in options and target_type == "chat",
            ignore_forwarded=True,
        )
        logs.debug(f"[SHIFT] 转发完成 - 从 {source} 到 {target_id}")
        
        media_type = message.media.value if message.media else "text"
        update_stats(source, target_id, media_type)


async def loosely_forward(
    notifier: Optional[Message],
    message: Message,
    chat_id: int,
    options: List[AVAILABLE_OPTIONS_TYPE],
    disable_notification: bool = False,
    ignore_forwarded: bool = False,
    _chain_depth: int = 0,  # 防止无限递归的深度计数器
):
    # 防止无限递归，最大链长度为10
    if _chain_depth > 10:
        logs.warning(f"[SHIFT] 转发链深度超过限制，停止转发")
        return

    # 找訊息類型video、document...
    # 如果不忽略转发，并且消息是转发的，则跳过
    if not ignore_forwarded and message.forward_from:
        return

    media_type = message.media.value if message.media else "text"
    should_forward = False
    
    if (not options) or "all" in options:
        should_forward = True
    elif media_type in options:
        should_forward = True
    else:
        logs.debug("skip message type: %s", media_type)
        return
    
    if should_forward:
        # 执行转发
        await forward_messages(
            chat_id, message.chat.id, [message.id], disable_notification, notifier
        )
        
        # 检查目标频道是否有下一级转发规则
        next_rule_str = sqlite.get(f"shift.{chat_id}")
        if next_rule_str:
            try:
                next_rule = json.loads(next_rule_str)
                if not next_rule.get("paused", False):
                    next_target_id = int(next_rule["target_id"])

                    # 在运行时再次检查循环（双重保障）
                    is_circular, _ = is_circular_forward(message.chat.id, next_target_id)
                    if is_circular:
                        logs.warning(f"[SHIFT] 检测到运行时循环，停止转发链: {message.chat.id} -> {next_target_id}")
                        return

                    next_options = next_rule.get("options", ["all"])
                    next_target_type = next_rule.get("target_type", "chat")

                    logs.debug(f"[SHIFT] 检测到转发链，继续转发到 {next_target_id} (深度: {_chain_depth + 1})")

                    # 递归调用，继续转发链
                    await loosely_forward(
                        notifier,
                        message,  # 使用原始消息
                        next_target_id,
                        next_options,
                        disable_notification="silent" in next_options and next_target_type == "chat",
                        ignore_forwarded=True,  # 在链式转发中总是忽略转发标记
                        _chain_depth=_chain_depth + 1
                    )
            except (json.JSONDecodeError, KeyError, TypeError) as e:
                logs.error(f"[SHIFT] 解析下一跳规则失败: {e}")


async def forward_messages(
    cid: int,
    from_id: int,
    message_ids: List[int],
    disable_notification: bool,
    notifier: Optional["Message"],
):
    try:
        await bot.forward_messages(
            cid, from_id, message_ids, disable_notification=disable_notification
        )
    except FloodWait as ex:
        min_time: int = ex.value  # type: ignore
        delay = min_time + uniform(0.5, 1.0)
        if notifier:
            await notifier.edit(f"⚠️ 触发 Flood 限制，暂停 {delay:.1f} 秒...")
        await sleep(delay)
        await forward_messages(
            cid, from_id, message_ids, disable_notification, notifier
        )
    except Exception:
        pass  # drop other errors


async def forward_group_media(
    cid: int,
    from_id: int,
    group_id: int,
    options: List[AVAILABLE_OPTIONS_TYPE],
    disable_notification: bool,
):
    try:
        msgs = await bot.get_media_group(from_id, group_id)
    except Exception:
        logs.debug("get_media_group failed for %d %d", from_id, group_id)
        return
    real_msgs = []
    for message in msgs:
        media_type = message.media.value if message.media else "text"
        if (not options) or "all" in options:
            real_msgs.append(message)
        elif media_type in options:
            real_msgs.append(message)
        else:
            logs.debug("skip message type: %s", media_type)
    if not real_msgs:
        return
    real_msgs_ids = [msg.id for msg in real_msgs]
    await forward_messages(cid, from_id, real_msgs_ids, disable_notification, None)


def add_or_replace_forward_group_media(
    cid: int,
    from_id: int,
    message_id: int,
    group_id: int,
    options: List[AVAILABLE_OPTIONS_TYPE],
    disable_notification: bool,
):
    key = f"shift.forward_group_media.{group_id}"
    scheduler.add_job(
        forward_group_media,
        trigger="date",
        args=(cid, from_id, message_id, options, disable_notification),
        id=key,
        name=key,
        replace_existing=True,
        run_date=datetime.datetime.now(pytz.timezone(Config.TIME_ZONE))
        + datetime.timedelta(seconds=4),
    )

