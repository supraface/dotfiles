local curl = require('plenary.curl')

--- @class LLMClient
--- ClaudeClient는 LLMClient 인터페이스를 구현합니다.
--- API 키는 환경변수 ANTHROPIC_API_KEY에서 자동으로 읽어옵니다.
local M = {}

local function get_api_key()
  local key = os.getenv("ANTHROPIC_API_KEY")
  if not key or key == "" then
    error("ANTHROPIC_API_KEY 환경변수가 설정되어 있지 않습니다.")
  end
  return key
end

--- Get available models from Claude using the official models API
--- @param callback? fun(err: string?, models: table?) Optional callback for async operation
--- @return table|nil
function M.list_models(callback)
  local url = 'https://api.anthropic.com/v1/models'
  local headers = {
    ['x-api-key'] = get_api_key(),
    ['Content-Type'] = 'application/json',
    ['anthropic-version'] = '2023-06-01',
  }

  if callback then
    -- Async request
    curl.get(url, {
      headers = headers,
      callback = function(response)
        if response.status == 200 then
          local success, data = pcall(vim.json.decode, response.body)
          if success then
            callback(nil, data.data)
          else
            callback('Failed to parse response JSON', nil)
          end
        else
          callback('HTTP error: ' .. response.status .. ' - ' .. (response.body or ''), nil)
        end
      end,
    })
  else
    -- Sync request
    local response = curl.get(url, {
      headers = headers,
    })

    if response.status == 200 then
      local success, data = pcall(vim.json.decode, response.body)
      if success then
        return data.data
      else
        error('Failed to parse response JSON')
      end
    else
      error('HTTP error: ' .. response.status .. ' - ' .. (response.body or ''))
    end
  end
end

--- Send a chat completion request to Claude (LLMClient 인터페이스)
--- @param request table
--- @param callback? fun(err: string?, response: table?) Optional callback for async operation
--- @return table|nil
function M.chat_complete(request, callback)
  local url = 'https://api.anthropic.com/v1/messages'
  local headers = {
    ['x-api-key'] = get_api_key(),
    ['Content-Type'] = 'application/json',
    ['anthropic-version'] = '2023-06-01',
  }

  -- Input validation
  if not request then
    error('Request is required')
  end

  if type(request) ~= 'table' then
    error('Request must be a table')
  end

  if not request.messages or type(request.messages) ~= 'table' or #request.messages == 0 then
    error('Messages array is required and must not be empty')
  end

  if not request.max_tokens or type(request.max_tokens) ~= 'number' or request.max_tokens < 1 then
    error('Max tokens is required and must be a positive number')
  end

  -- Validate each message
  for i, message in ipairs(request.messages) do
    if type(message) ~= 'table' then
      error('Message ' .. i .. ' must be a table')
    end

    if not message.role or type(message.role) ~= 'string' then
      error('Message ' .. i .. ' must have a role (string)')
    end

    if not message.content or type(message.content) ~= 'string' then
      error('Message ' .. i .. ' must have content (string)')
    end

    -- Validate role values for Claude
    local valid_roles = { user = true, assistant = true }
    if not valid_roles[message.role] then
      error('Message ' .. i .. ' has invalid role: ' .. message.role .. ' (Claude only supports user/assistant)')
    end
  end

  -- Validate optional parameters
  if request.model and type(request.model) ~= 'string' then
    error('Model must be a string')
  end

  if request.temperature and (type(request.temperature) ~= 'number' or request.temperature < 0 or request.temperature > 1) then
    error('Temperature must be a number between 0 and 1')
  end

  if request.stream and type(request.stream) ~= 'boolean' then
    error('Stream must be a boolean')
  end

  local body = vim.json.encode({
    model = request.model or 'claude-3-5-sonnet-20241022',
    max_tokens = request.max_tokens,
    messages = request.messages,
    temperature = request.temperature or 0.7,
    stream = request.stream or false,
  })

  if callback then
    -- Async request
    curl.post(url, {
      headers = headers,
      body = body,
      callback = function(response)
        if response.status == 200 then
          local success, data = pcall(vim.json.decode, response.body)
          if success then
            callback(nil, {
              content = data.content[1].text,
              model = data.model,
              usage = data.usage,
            })
          else
            callback('Failed to parse response JSON', nil)
          end
        else
          callback('HTTP error: ' .. response.status .. ' - ' .. (response.body or ''), nil)
        end
      end,
    })
  else
    -- Sync request
    local response = curl.post(url, {
      headers = headers,
      body = body,
    })

    if response.status == 200 then
      local success, data = pcall(vim.json.decode, response.body)
      if success then
        return {
          content = data.content[1].text,
          model = data.model,
          usage = data.usage,
        }
      else
        error('Failed to parse response JSON')
      end
    else
      error('HTTP error: ' .. response.status .. ' - ' .. (response.body or ''))
    end
  end
end

return M
