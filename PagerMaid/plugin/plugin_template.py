"""
PagerMaid 插件开发模板
----------------------
复制本文件，重命名后即可快速开发新插件。
"""
from pagermaid import bot
from pagermaid.listener import listener

@listener(command="template", description="插件模板示例，回复 hello world。")
async def template(context):
    await context.edit("Hello, world! 这是插件模板。")
