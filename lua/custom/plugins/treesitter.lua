local has_nix_deps, nix_deps = pcall(require, 'nix-deps')
local languages = vim.json.decode(table.concat(vim.fn.readfile(vim.fn.stdpath 'config' .. '/treesitter-parsers.json'), '\n'))

local function start_treesitter(buffer)
  if not vim.api.nvim_buf_is_loaded(buffer) then
    return
  end
  local language = vim.treesitter.language.get_lang(vim.bo[buffer].filetype)
  if not language or #vim.api.nvim_get_runtime_file('parser/' .. language .. '.so', false) == 0 then
    return
  end
  vim.treesitter.start(buffer, language)
  if vim.bo[buffer].filetype ~= 'ruby' then
    vim.bo[buffer].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
  end
end

return {
  {
    'nvim-treesitter/nvim-treesitter',
    branch = 'main',
    dir = has_nix_deps and nix_deps.treesitter or nil,
    lazy = false,
    build = not has_nix_deps and ':TSUpdate' or nil,
    config = function()
      vim.api.nvim_create_autocmd('FileType', {
        group = vim.api.nvim_create_augroup('ConfigTreesitter', { clear = true }),
        callback = function(event) start_treesitter(event.buf) end,
      })
      if not has_nix_deps then
        require('nvim-treesitter').install(languages):await(function(failure)
          vim.schedule(function()
            if failure then
              vim.notify('Tree-sitter installation failed: ' .. tostring(failure), vim.log.levels.ERROR)
              return
            end
            for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
              start_treesitter(buffer)
            end
          end)
        end)
      end
    end,
  },
  {
    'nvim-treesitter/nvim-treesitter-textobjects',
    branch = 'main',
    dir = has_nix_deps and nix_deps.textobjects or nil,
    lazy = false,
    config = function()
      require('nvim-treesitter-textobjects').setup {
        select = { lookahead = true },
        move = { set_jumps = true },
      }

      for key, capture in pairs {
        af = '@function.outer',
        ['if'] = '@function.inner',
        ac = '@class.outer',
        ic = '@class.inner',
      } do
        vim.keymap.set({ 'x', 'o' }, key, function() require('nvim-treesitter-textobjects.select').select_textobject(capture, 'textobjects') end)
      end

      for key, movement in pairs {
        [']m'] = { 'goto_next_start', '@function.outer' },
        [']]'] = { 'goto_next_start', '@class.outer' },
        ['[m'] = { 'goto_previous_start', '@function.outer' },
        ['[['] = { 'goto_previous_start', '@class.outer' },
      } do
        vim.keymap.set({ 'n', 'x', 'o' }, key, function() require('nvim-treesitter-textobjects.move')[movement[1]](movement[2], 'textobjects') end)
      end

      vim.keymap.set('n', '<leader>a', function() require('nvim-treesitter-textobjects.swap').swap_next '@parameter.inner' end)
      vim.keymap.set('n', '<leader>A', function() require('nvim-treesitter-textobjects.swap').swap_previous '@parameter.inner' end)
    end,
  },
}
