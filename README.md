# groq-nvim

A Neovim plugin for interacting with the Groq API.

## Getting Started

If you don't have it already, install Packer with this command

```sh
git clone --depth 1 https://github.com/wbthomason/packer.nvim\
 ~/.local/share/nvim/site/pack/packer/start/packer.nvim
```

With that installed, we can now add our packer setup to our `~/.config/nvim/init.lua`

### Lazy Setup

```lua
---@type LazySpec
return {
  "cdreetz/groq-nvim",
  enabled = true,

  dependencies = { "nvim-lua/plenary.nvim" },
  config = function()
    require("groq-nvim").setup({
      api_key = "your_groq_api_key",
      model = "llama3-70b-8192",
    })
  end,
}
```

### Packer Setup

```lua
-- packer setup
vim.cmd [[packadd packer.nvim]]

require('packer').startup(function(use)
    use 'wbthomason/packer.nvim'
    use 'nvim-lua/plenary.nvim'

    -- Add groq-nvim plugin from GitHub
    use {
        'cdreetz/groq-nvim',
        requires = { 'nvim-lua/plenary.nvim' },
        config = function()
            require('groq-nvim').setup({
                api_key = "your_groq_api_key",
                model = "llama3-70b-8192"
            })
        end
    }
end)
```

## Commands

These are the current available commands

```vim
- :GroqGenerate

- :GroqGenerateWithContext

- :GroqEdit
```

To use `GroqGenerate`, all you do is `:GroqGenerate` your prompt and the code will be generated at the place of the cursor

To use `GroqGenerateWithContext`, you start with `:GroqGenerateWithContext` your prompt `/path/to/context/file.py`

To use `GroqEdit`, you begin by selecting some text, typically in visual mode, and then using `:GroqEdit` your prompt the selected code will be rewritten based on your prompt

## Examples

### Groq Generate

```vim
:GroqGenerate write a python function that prints hello world
```

![](https://github.com/cdreetz/groq-nvim/blob/master/public/GroqGenerateGif.gif)

### Groq Edit

```vim
:GroqEdit rewrite this method while adding debug lines to it
```

![](https://github.com/cdreetz/groq-nvim/blob/master/public/GroqEditGif.gif)

### Groq Generate With Context

```vim
:GroqGenerateWithContext write a new version of the method found in this file ./file.py
```
