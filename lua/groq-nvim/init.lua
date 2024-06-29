-- groq-nvim.lua
local M = {}
local curl = require('plenary.curl')
local json = vim.json

-- Configuration
M.config = {
  api_url = "https://api.groq.com/openai/v1/chat/completions",
}

M.original_text = nil
M.original_range = nil

-- Debugging function
local function log(message)
  vim.fn.writefile({message}, '/tmp/groq_nvim_debug.log', 'a')
end

-- Set up the plugin
function M.setup(opts)
  M.config = vim.tbl_extend("force", M.config, opts or {})
  if not M.config.api_key then
    error("Groq API key not set. Please set it in the setup function.")
  end
  -- Set up commands
  vim.api.nvim_create_user_command("GroqGenerate", M.generate_code, {nargs = 1})
  vim.api.nvim_create_user_command("GroqGenerateWithContext", M.generate_code_with_context, {nargs = '+', complete = 'file'})
  vim.api.nvim_create_user_command("GroqEdit", M.edit_code, {range = true, nargs = '?'})
  --vim.api.nvim_create_user_command("GroqApprove", M.approve_changes, {})
end

-- Helper function to make API calls with streaming
local function call_groq_api_stream(messages, callback)
  local job_id = vim.fn.jobstart({"curl", "-sS", "-N",
    M.config.api_url,
    "-H", "Authorization: Bearer " .. M.config.api_key,
    "-H", "Content-Type: application/json",
    "-d", json.encode({
      model = M.config.model,
      messages = messages,
      stream = true
    })
  }, {
    on_stdout = function(_, data)
      for _, line in ipairs(data) do
        if line:sub(1, 6) == "data: " then
          local raw_data = line:sub(7)
          if raw_data ~= "[DONE]" then
            local success, parsed_data = pcall(json.decode, raw_data)
            if success and parsed_data.choices and parsed_data.choices[1].delta.content then
              callback(parsed_data.choices[1].delta.content)
            end
          end
        end
      end
    end,
    on_exit = function()
      callback(nil)  -- Signal end of stream
    end
  })
end

-- Function to generate code
function M.generate_code(opts)
  local prompt = opts.args
  local messages = {
	  {role = "system", content = "You are a helpful coding assistant. Based on the users prompt, write the code or response.  If the user is asking you to write some code, only generate the code they need with no additional formatting or text. The code you generate is written directly to the current file so make sure it is valid code."},
	  {role = "user", content = prompt}
  }
  
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local lines = {}
  
  call_groq_api_stream(messages, function(content)
    if content then
      local new_lines = vim.split(content, "\n", true)
      for i, line in ipairs(new_lines) do
        if i == 1 then
          -- Append to the current line
          local current_line = vim.api.nvim_buf_get_lines(0, row-1, row, false)[1]
          vim.api.nvim_buf_set_lines(0, row-1, row, false, {current_line .. line})
        else
          -- Insert new lines
          vim.api.nvim_buf_set_lines(0, row, row, false, {line})
          row = row + 1
        end
      end
      vim.api.nvim_win_set_cursor(0, {row, col})
    else
      -- End of stream, do any cleanup if needed
    end
  end)
end

-- Function to edit code
function M.edit_code(opts)
  local start_line = opts.line1 - 1
  local end_line = opts.line2
  local selected_text = table.concat(vim.api.nvim_buf_get_lines(0, start_line, end_line, false), "\n")
  local prompt = opts.args
  local messages = {
	  {role = "system", content = "You are a helpful coding assistant. Based on the users prompt, and the selected code, rewrite the selection with any necessary edits based on the users prompt.  All of the selected code will be deleted so make sure you rewrite it by incorporating both the old code and the new changes. The user is asking you to write some code, only generate the code they need with no additional formatting or text. The code you generate is written directly to the current file so make sure it is valid code."},
	  {role = "user", content = prompt .. selected_text}
  }
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local lines = {}
  
  -- Clear the selected lines
  vim.api.nvim_buf_set_lines(0, start_line, end_line, false, {})
  
  call_groq_api_stream(messages, function(content)
    if content then
      local new_lines = vim.split(content, "\n", true)
      for i, line in ipairs(new_lines) do
        if i == 1 then
          -- Append to the current line
          local current_line = vim.api.nvim_buf_get_lines(0, row-1, row, false)[1]
          vim.api.nvim_buf_set_lines(0, row-1, row, false, {current_line .. line})
        else
          -- Insert new lines
          vim.api.nvim_buf_set_lines(0, row, row, false, {line})
          row = row + 1
        end
      end
      vim.api.nvim_win_set_cursor(0, {row, col})
    else
      -- End of stream, do any cleanup if needed
    end
  end)
end

function M.get_file_content(file_path)
  local file = io.open(file_path, "rb")
  if not file then
    print("Error: Unable to open file " .. file_path)
    return nil
  end
  local content = file:read("*a")
  file:close()
  return content
end

function M.generate_code_with_context(opts)
  --local prompt = opts.args
  local prompt = table.concat(opts.fargs, " ", 1, #opts.fargs - 1)
  local context = opts.fargs[#opts.fargs]
  local file_content = M.get_file_content(context)

  if not file_content then
    print("Error: Unable to read context file")
    return
  end

  local messages = {
    {role = "system", content = "You are a helpful coding assistant. Based on the users prompt and context, write the code or response.  If the user is asking you to write some code, only generate the code they need with no additional formatting or text. The code you generate is written directly to the current file so make sure it is valid code."},
    {role = "user", content = prompt .. file_content}
  }
  
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local lines = {}
  
  call_groq_api_stream(messages, function(content)
    if content then
      local new_lines = vim.split(content, "\n", true)
      for i, line in ipairs(new_lines) do
        if i == 1 then
          -- Append to the current line
          local current_line = vim.api.nvim_buf_get_lines(0, row-1, row, false)[1]
          vim.api.nvim_buf_set_lines(0, row-1, row, false, {current_line .. line})
        else
          -- Insert new lines
          vim.api.nvim_buf_set_lines(0, row, row, false, {line})
          row = row + 1
        end
      end
      vim.api.nvim_win_set_cursor(0, {row, col})
    else
      -- End of stream, do any cleanup if needed
    end
  end)
end



return M
