from pagermaid import bot, log, version
from pagermaid.listener import listener
from asyncio import sleep
from datetime import timedelta
from telethon.tl.types import ChannelParticipantsAdmins
from pagermaid.utils import alias_command


async def removemsg(context, last_name, count):
    count_buffer = 0
    target = await context.get_reply_message()
    async for message in context.client.iter_messages(context.chat_id, from_user=target.from_id):
        if count_buffer == count:
            break
        await message.delete()
        count_buffer += 1
    await log(f'删除【{last_name}】消息完成，共删除{count_buffer}条消息')
    await context.edit(f'已删除【{last_name}】这个b最近{count_buffer}条污言秽语')


@listener(is_plugin=True, outgoing=True, command=alias_command("kickanddm"),
          description="回复你要删除消息和踢的人或者要禁言的人\n指令：\n-k直接删除消息并踢人\n-k 10禁言10秒（tg不支持60秒以下的时间，少于60变成永久）并删除最近999条消息\n⚠️k后面带时间的只是禁言，不带时间的直接踢")
async def kickanddm(context):
    # 是否在群组
    if context.is_group:
        reply = await context.get_reply_message()
        # 是否回复了消息
        if reply:
            # 是否是管理员
            try:
                chat = await context.get_chat()
                admins = await context.client.get_participants(chat, filter=ChannelParticipantsAdmins)
                admins_ids = [a.id for a in admins]
                if context.sender_id not in admins_ids:
                    await context.edit('需要管理员权限')
                    await sleep(5)
                    await context.delete()
                    return False
            except:
                await context.edit('发生错误,无法获取本群名单。')
                await sleep(5)
                await context.delete()
                return False
            else:
                action = context.parameter
                if reply.sender.last_name is None:
                    if reply.sender.first_name is None:
                        last_name = ''
                    else:
                        last_name = reply.sender.first_name
                else:
                    last_name = reply.sender.last_name

                if len(action) == 1:
                    try:
                        await context.client.edit_permissions(context.chat_id, reply.sender.id,
                                                   timedelta(seconds=int(action[0].replace(' ', ''))),
                                                   send_messages=False,
                                                   send_media=False, send_stickers=False, send_gifs=False,
                                                   send_games=False,
                                                   send_inline=False, send_polls=False, invite_users=False,
                                                   change_info=False,
                                                   pin_messages=False)
                        await context.edit(f'已封禁【{last_name}】')
                        await removemsg(context, last_name, 0)
                    except:
                        await context.edit('🤏🏼给爷等着，迟早ban了你')
                        await sleep(5)
                        await context.delete()
                        return
                else:
                    try:
                        await context.client.edit_permissions(context.chat_id, reply.sender.id,
                                                   timedelta(seconds=60),
                                                   send_messages=False,
                                                   send_media=False, send_stickers=False, send_gifs=False,
                                                   send_games=False,
                                                   send_inline=False, send_polls=False, invite_users=False,
                                                   change_info=False,
                                                   pin_messages=False)
                        await context.edit(f'已封禁【{last_name}】')
                        await removemsg(context, last_name, 0)
                        await context.client.edit_permissions(context.chat_id, reply.sender.id, view_messages=False)
                        await context.edit(f'已封禁【{last_name}】')
                    except:
                        await context.edit('🤏🏼给爷等着，迟早ban了你')
                        await sleep(5)
                        await context.delete()
                        return
        else:
            await context.edit('请回复消息使用')
            await sleep(5)
            await context.delete()
    else:
        await context.edit('请在群组中使用')
        await sleep(5)
        await context.delete()