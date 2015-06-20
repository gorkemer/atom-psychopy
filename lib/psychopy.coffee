PsychopyView = require './psychopy-view'

module.exports =
  # Define configuration capabilities
  config:
    pythonRuntime:
      title: 'Python Runtime'
      type: 'string'
      default: '/Applications/PsychoPy2.app/Contents/MacOS/python'
      description: 'Location of the python binary that comes bundled with the standalone PsychoPy version'
      order: 1
    PYTHONHOME:
      title: 'PYTHONHOME variable'
      type: 'string'
      default: '/Applications/PsychoPy2.app/Contents/Resources'
      description: 'Location of the resources folder of the standalone PsychoPy version'
      order: 2
    enableExecTime:
      title: 'Output the time it took to execute the script'
      type: 'boolean'
      default: true
      order: 3
    escapeConsoleOutput:
      title: 'HTML escape console output'
      type: 'boolean'
      default: true
      order: 4
    scrollWithOutput:
      title: 'Scroll with output'
      type: 'boolean'
      default: true
      order: 5

  psychopyView: null

  activate: (state) ->
    @psychopyView = new PsychopyView(state.psychopyViewState)

  deactivate: ->
    @psychopyView.close()

  serialize: ->
    psychopyViewState: @psychopyView.serialize()
