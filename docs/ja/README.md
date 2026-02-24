# git-wt.nvim

[git-wt](https://github.com/k1LoW/git-wt) を Neovim から操作するためのプラグインです。

Telescope ピッカー（または `vim.ui.select`）から worktree を切り替えると、Neovim の作業ディレクトリが自動的に変更され、neo-tree や lualine などのプラグインも連動します。

[English documentation](../../README.md)

## 必要なもの

- Neovim >= 0.10
- [git-wt](https://github.com/k1LoW/git-wt) CLI
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)（任意。なければ `vim.ui.select` にフォールバック）

## インストール

### lazy.nvim

```lua
{
  "WataruNishimura/git-wt.nvim",
  dependencies = { "nvim-telescope/telescope.nvim" }, -- なくても動作します
  config = function()
    require("git-wt").setup()
  end,
}
```

### packer.nvim

```lua
use {
  "WataruNishimura/git-wt.nvim",
  config = function()
    require("git-wt").setup()
  end,
}
```

## コマンド

| コマンド | 説明 |
|---|---|
| `:GitWt` | ピッカーを開いて worktree を選択・切り替え |
| `:GitWt list` | worktree の一覧を表示 |
| `:GitWt switch <branch>` | 指定ブランチの worktree に切り替え |
| `:GitWt create <branch> [start-point]` | 新しい worktree を作成して切り替え |
| `:GitWt delete <branch> [--force]` | worktree を削除 |
| `:GitWt status` | 現在の worktree 情報を表示 |

サブコマンドとブランチ名はタブ補完に対応しています。

## Telescope ピッカー

Telescope がインストールされている場合、`:GitWt` で Telescope ピッカーが開きます。

| キー | 操作 |
|---|---|
| `<CR>` | 選択した worktree に切り替え |
| `<C-d>` | 選択した worktree を削除（確認あり） |

Telescope がない場合は `vim.ui.select` が使われます。

## 設定

```lua
require("git-wt").setup({
  -- git-wt バイナリのパス（デフォルト: "git-wt"）
  bin = "git-wt",

  -- 切り替え時に通知を表示（デフォルト: true）
  notify = true,

  -- ディレクトリ変更後に実行する関数（デフォルト: {}）
  hooks = {
    -- 例: 切り替え後に neo-tree をリフレッシュ
    -- function(dir)
    --   vim.cmd("Neotree dir=" .. dir)
    -- end,
  },
})
```

## 仕組み

1. `git-wt --json --nocd` で worktree 一覧を JSON として取得
2. 切り替え時に `vim.cmd("cd ...")` でグローバルな作業ディレクトリを変更
3. Neovim の `DirChanged` autocmd が発火
4. `DirChanged` を監視しているプラグイン（neo-tree、lualine など）が自動的に更新

## Lua API

カスタムキーマップやワークフロー用に Lua API を直接使うこともできます。

```lua
local git_wt = require("git-wt")

-- worktree の一覧を取得
git_wt.list(function(worktrees)
  -- worktrees: { { path, branch, head, bare, current }, ... }
end)

-- パスを指定して worktree に切り替え
git_wt.switch("/path/to/worktree")

-- 新しい worktree を作成
git_wt.create("feature-branch", "origin/main", function(path)
  -- 失敗時は path が nil
end)

-- worktree を削除
git_wt.delete("feature-branch", false, function(ok) end)  -- 安全な削除
git_wt.delete("feature-branch", true, function(ok) end)   -- 強制削除
```

## 謝辞

このプラグインは [@k1LoW](https://github.com/k1LoW) 氏の [git-wt](https://github.com/k1LoW/git-wt) をベースにしています。シンプルかつ強力な Git worktree 管理 CLI を作ってくださったことに感謝します。

## ライセンス

MIT
