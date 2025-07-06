# AutoFileName.nvim

[English](README.md) | [日本語](doc/README_ja.md) | [简体中文](doc/README_zh-CN.md)

AutoFileName.nvim is a Neovim plugin that automatically generates appropriate filenames based on the date and content when creating and saving new note files. It helps you save the effort of manually thinking of filenames, supporting efficient note management.

## Features

*   **Automatic Filename Generation**: Automatically generates filenames based on user-configurable format strings (e.g., `{{strftime:%Y%m%dT%H%M%S}}_{{first_line}}`).
    *   `{{strftime:...}}`: Inserts date and time in various formats (e.g., `{{strftime:%Y%m%d}}` will result in `20230706`).
    *   `{{first_line}}`: Includes the content of the first non-empty line of the buffer in the filename. Characters unsuitable for filenames are automatically sanitized.
    *   `{{lua:...}}`: Executes arbitrary Lua code and includes its return value in the filename. The result is automatically sanitized to be safe for filenames.
*   **Auto-save Command**: Provides the `:AutoSaveNote` command to save the current buffer's content with the automatically generated filename.
*   **File Extension Setting**: Allows configuring the file extension (e.g., `.md`, `.txt`) for saved files.
*   **Filename Conflict Resolution**: If a file with the same name already exists, a sequential number (e.g., `filename-1.md`) is automatically appended to avoid conflicts.
*   **Filename Length Limit**: Automatically truncates generated filenames to comply with operating system filename limits (typically 255 characters).
*   **Multi-language Support (i18n)**: Supports English, Japanese, and Simplified Chinese.

## Installation

Example using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
-- init.lua or plugins.lua
{
  'anyumuenyumuboto/AutoFileName.nvim', -- Replace with your actual GitHub repository path
  config = function()
    require('autofilename').setup({
      -- Set your options here
      -- Example:
      -- extension = ".txt",
      -- filename_format = "{{strftime:%Y-%m-%d}}_{{first_line}}",
      -- lang = "en", -- 'en', 'ja', 'zh-CN'
    })
  end
}
```

## Usage

1.  Open a new Neovim buffer.
2.  Write your note content. The first non-empty line will be used as the `{{first_line}}` placeholder.
3.  Execute `:AutoSaveNote` in command mode.
4.  The file will be saved to the current working directory based on your configured format and extension.

## Configuration

You can customize the plugin's behavior by passing a table to the `require('autofilename').setup({})` function.

Available options:

*   `lang` (string, default: `"en"`): Sets the display language for plugin messages. Available options are `"en"` (English), `"ja"` (Japanese), `"zh-CN"` (Simplified Chinese). If not set, it attempts to auto-detect from the system's `LANG` environment variable.
*   `extension` (string, default: `".md"`): Specifies the default extension for saved files.
*   `filename_format` (string, default: `{{strftime:%Y%m%dT%H%M%S}}_{{first_line}}`): Defines the format for generating filenames. The following placeholders are available:
    *   `{{strftime:format}}`: Accepts a `strftime` format string, identical to `os.date`, to insert date and time. (e.g., `{{strftime:%Y-%m-%d_%H%M}}`)
    *   `{{first_line}}`: Inserts the content of the current buffer's first non-empty line. Characters unsuitable for filenames are automatically converted to safe alternatives.
    *   `{{lua:code}}`: Executes the specified Lua code and inserts its result. The result is automatically converted to safe filename characters. (e.g., `{{lua:vim.fn.hostname()}}` to insert the hostname)
*   `save_directory` (string, default: `nil`): Specifies the default directory to save notes. If `nil`, files will be saved in the current working directory.
*   `max_filename_length` (number, default: `255`): The maximum length for the generated filename (including extension). Prevents exceeding OS limits.

### Configuration Example

```lua
require('autofilename').setup({
  extension = ".txt", -- Save as .txt file
  filename_format = "{{strftime:%Y%m%d-%H%M%S}}_{{lua:os.getenv('USER')}}_{{first_line}}",
  lang = "en", -- Use English messages
  save_directory = "~/notes", -- Save to ~/notes directory
  max_filename_length = 150, -- Limit filename to 150 characters
})
})
```

## Development

### Setting up Development Environment

1.  Clone the repository:
    ```bash
    git clone https://github.com/your_github_username/AutoFileName.nvim.git
    cd AutoFileName.nvim
    ```
2.  Run the `nvim_dev` task to launch the development environment (requires Taskfile):
    ```bash
    task nvim_dev
    ```
    This will start Neovim with `dev_config/init.lua` as its configuration file in a clean state.

## Contribution

Bug reports, feature requests, and pull requests are welcome.

## License

This project is licensed under the MIT License. See the `LICENSE` file for details.
