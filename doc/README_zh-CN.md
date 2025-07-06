# AutoFileName.nvim

[English](../README.md) | [日本語](README_ja.md) | [简体中文](README_zh-CN.md)

AutoFileName.nvim是一个Neovim插件，用于在新创建笔记文件并保存时，自动根据日期和内容生成合适的S文件名。它能帮助您省去手动命名文件的麻烦，从而实现高效的笔记管理。

## 功能

*   **文件名自动生成**: 根据用户可配置的格式字符串（例如：`{{strftime:%Y%m%dT%H%M%S}}_{{first_line}}`）自动生成文件名。
    *   `{{strftime:...}}`: 插入各种格式的日期和时间（例如：`{{strftime:%Y%m%d}}` 将生成 `20230706`）。
    *   `{{first_line}}`: 将缓冲区中第一个非空行的内容包含在文件名中。文件名中不合适的字符会自动进行净化处理。
    *   `{{lua:...}}`: 执行任意Lua代码，并将其返回值包含在文件名中。结果会自动进行净化处理以符合文件名规范。
*   **自动保存命令**: 提供 `:AutoSaveNote` 命令，以自动生成的文件名保存当前缓冲区内容。
*   **文件扩展名设置**: 可配置要保存的文件扩展名（例如：`.md`, `.txt`）。
*   **文件名冲突解决**: 如果文件名已存在，将自动添加序号（例如：`filename-1.md`）以避免冲突。
*   **文件名长度限制**: 为符合操作系统的文件名限制（通常为255个字符），生成的文件名会自动截断。
*   **多语言支持 (i18n)**: 支持英语、日语和简体中文。

## 安装

如果使用 [lazy.nvim](https://github.com/folke/lazy.nvim) 的示例：

```lua
-- init.lua 或 plugins.lua
{
  'anyumuenyumuboto/AutoFileName.nvim', -- 请替换为您的实际GitHub仓库路径
  config = function()
    require('autofilename').setup({
      -- 在此处设置选项
      -- 例如：
      -- extension = ".txt",
      -- filename_format = "{{strftime:%Y-%m-%d}}_{{first_line}}",
      -- lang = "ja", -- 'en', 'ja', 'zh-CN'
    })
  end
}
```

## 使用方法

1.  打开一个新的Neovim缓冲区。
2.  输入笔记内容。第一个非空行将用作 `{{first_line}}` 占位符。
3.  在命令模式下执行 `:AutoSaveNote`。
4.  文件将根据配置的格式和扩展名保存到当前工作目录。

## 配置

您可以通过将表格传递给 `require('autofilename').setup({})` 函数来自定义插件的行为。

可用选项：

*   `lang` (string, 默认值: `"en"`): 设置插件消息的显示语言。可用选项有 `"en"` (英语), `"ja"` (日语), `"zh-CN"` (简体中文)。如果未设置，将尝试从系统环境变量 `LANG` 自动检测。
*   `extension` (string, 默认值: `".md"`): 指定保存文件的默认扩展名。
*   `filename_format` (string, 默认值: `{{strftime:%Y%m%dT%H%M%S}}_{{first_line}}`): 指定文件名的生成格式。支持以下占位符：
    *   `{{strftime:format}}`: 接受与 `os.date` 函数相同的strftime格式字符串，并插入日期和时间（例如：`{{strftime:%Y-%m-%d_%H%M}}`）。
    *   `{{first_line}}`: 插入当前缓冲区中第一个非空行的内容。文件名中不合适的字符将自动转换为安全字符。
    *   `{{lua:code}}`: 执行指定的Lua代码并插入其结果。结果将自动转换为安全的文件名字符（例如：`{{lua:vim.fn.hostname()}}` 插入主机名）。
*   `save_directory` (string, 默认值: `nil`): 指定默认保存笔记的目录。如果为 `nil`，文件将保存到当前工作目录。
*   `max_filename_length` (number, 默认值: `255`): 生成文件名的最大长度（包括扩展名）。用于防止超出操作系统限制。

### 配置示例

```lua
require('autofilename').setup({
  extension = ".txt", -- 保存为.txt文件
  filename_format = "{{strftime:%Y%m%d-%H%M%S}}_{{lua:os.getenv('USER')}}_{{first_line}}",
  lang = "zh-CN", -- 使用简体中文消息
  save_directory = "~/notes", -- 保存到 ~/notes 目录
  max_filename_length = 150, -- 文件名限制为150个字符
})
```

## 开发

### 开发环境设置

1.  克隆仓库：
    ```bash
    git clone https://github.com/your_github_username/AutoFileName.nvim.git
    cd AutoFileName.nvim
    ```
2.  执行 `nvim_dev` 任务启动开发环境 (需要 Taskfile)：
    ```bash
    task nvim_dev
    ```
    这将以 `dev_config/init.lua` 作为配置文件启动Neovim的干净实例。

## 贡献

欢迎提交bug报告、功能请求和拉取请求。

## 许可证

本项目根据MIT许可证发布。更多详情请参阅 `LICENSE` 文件。
