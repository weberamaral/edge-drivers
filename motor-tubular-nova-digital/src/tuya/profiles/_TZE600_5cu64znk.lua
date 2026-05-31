return {
  [1] = {
    name = "windowShade",
    handler = "window_shade"
  },
  [3] = {
    name = "windowShadeLevel",
    handler = "window_shade_level"
  },

  [13] = {
    name = "battery",
    handler = "battery"
  },

  [5] = {
    name = "direction",
    handler = "direction"
  },

  commands = {
    openClosePause = {
      dp = 1,
      open = 0,
      pause = 1,
      close = 2
    }
  },

  preferences = {

    reverseDirection = {
      dp = 5
    },

    calibration = {
      dp = 16
    }
  }
}
