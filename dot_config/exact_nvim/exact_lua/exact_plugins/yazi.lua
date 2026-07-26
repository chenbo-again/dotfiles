return {
  {
    "mikavilpas/yazi.nvim",
    dependencies = {
      { "nvim-lua/plenary.nvim", lazy = true },
    },
    cmd = "Yazi",
    keys = {
      {
        "<leader>fy",
        mode = { "n", "v" },
        "<cmd>Yazi<cr>",
        desc = "Open Yazi at Current File",
      },
      {
        "<leader>fY",
        "<cmd>Yazi cwd<cr>",
        desc = "Open Yazi in Working Directory",
      },
      {
        "<c-up>",
        "<cmd>Yazi toggle<cr>",
        desc = "Resume Last Yazi Session",
      },
    },
    opts = {
      open_for_directories = false,
      integrations = {
        grep_in_directory = "snacks.picker",
        grep_in_selected_files = "snacks.picker",
      },
    },
  },
}
