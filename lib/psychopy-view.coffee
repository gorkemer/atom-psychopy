{BufferedProcess, CompositeDisposable} = require 'atom'
{View, $$} = require 'atom-space-pen-views'
CodeContext = require './code-context'
HeaderView = require './header-view'
AnsiFilter = require 'ansi-to-html'
stripAnsi = require 'strip-ansi'
_ = require 'underscore'

# Runs a portion of a script through an interpreter and displays it line by line
module.exports =
class PsychopyView extends View
  @bufferedProcess: null
  @results: ""

  @content: ->
    @div =>
      @subview 'headerView', new HeaderView()

      # Display layout and outlets
      css = 'tool-panel panel panel-bottom padding psychopy-view
        native-key-bindings'
      @div class: css, outlet: 'psychopy', tabindex: -1, =>
        @div class: 'panel-body padded output', outlet: 'output'

  initialize: (serializeState, @runOptions) ->
    @subscriptions = new CompositeDisposable
    @subscriptions.add atom.commands.add 'atom-workspace',
      'core:cancel': => @close()
      'core:close': => @close()
      'psychopy:close-view': => @close()
      'psychopy:stop': => @stop()
      'psychopy:run': => @defaultRun()

    @ansiFilter = new AnsiFilter

  serialize: ->

  getShebang: (editor) ->
    text = editor.getText()
    lines = text.split("\n")
    firstLine = lines[0]
    return unless firstLine.match(/^#!/)

    firstLine.replace(/^#!\s*/, '')

  initCodeContext: (editor) ->
    filename = editor.getTitle()
    filepath = editor.getPath()
    selection = editor.getLastSelection()

    # If the selection was empty "select" ALL the text
    # This allows us to run on new files
    if selection.isEmpty()
      textSource = editor
    else
      textSource = selection

    codeContext = new CodeContext(filename, filepath, textSource)
    codeContext.selection = selection
    codeContext.shebang = @getShebang(editor)

    # Get language
    lang = @getLang editor

    if @validateLang lang
      codeContext.lang = lang

    return codeContext

  defaultRun: ->
    @resetView()
    codeContext = @buildCodeContext() # Until proven otherwise
    @start(codeContext) unless not codeContext?

  buildCodeContext: () ->
    # Get current editor
    editor = atom.workspace.getActiveTextEditor()
    # No editor available, do nothing
    return unless editor?

    codeContext = @initCodeContext(editor)

    if codeContext.filepath?
      codeContext.argType = 'File Based'
      editor.save()

    return codeContext

  start: (codeContext) ->

    # If language was not determined, do nothing
    if not codeContext.lang?
      # In the future we could handle a runner without the language being part
      # of the grammar map, using the options runner
      return

    commandContext = @setupRuntime codeContext
    @run commandContext.command, commandContext.args, codeContext if commandContext

  resetView: (title = 'Loading...') ->
    # Display window and load message

    # First run, create view
    atom.workspace.addBottomPanel(item: this) unless @hasParent()

    # Close any existing process and start a new one
    @stop()

    @headerView.title.text title
    @headerView.setStatus 'start'

    # Get script view ready
    @output.empty()

    # Remove the old script results
    @results = ""

  close: ->
    # Stop any running process and dismiss window
    @stop()
    @detach() if @hasParent()

  destroy: ->
    @subscriptions?.dispose()

  getLang: (editor) -> editor.getGrammar().name

  validateLang: (lang) ->
    err = null

    # Determine if no language is selected.
    if lang is not 'Python'
      err = $$ ->
        @p 'Psychopy can only run Python files. Duh!'

    if err?
      @handleError(err)
      return false

    return true

  extendedEnv: (otherEnv) ->
    mergedEnv = _.extend process.env, otherEnv

    for key,value of mergedEnv
      mergedEnv[key] = "#{value}".replace /"((?:[^"\\]|\\"|\\[^"])+)"/, '$1'
      mergedEnv[key] = mergedEnv[key].replace /'((?:[^'\\]|\\'|\\[^'])+)'/, '$1'

    mergedEnv

  setupRuntime: (codeContext) ->
    # Store information about the run
    commandContext = {}

    commandContext.command = atom.config.get 'psychopy.pythonRuntime'

    # Update header to show the lang and file name
    @headerView.title.text "#{codeContext.lang} - #{codeContext.filename}"

    commandContext.args = [codeContext.filepath]

    # Return setup information
    return commandContext

  handleError: (err) ->
    # Display error and kill process
    @headerView.title.text 'Error'
    @headerView.setStatus 'err'
    @output.append err
    @stop()

  run: (command, extraArgs, codeContext) ->
    startTime = new Date()

    # Default to where the user opened atom
    options =
      cwd: atom.project.getPaths()[0]
      env: @extendedEnv({'PYTHONHOME': atom.config.get 'psychopy.PYTHONHOME'})
    args = extraArgs

    stdout = (output) => @display 'stdout', output
    stderr = (output) => @display 'stderr', output
    exit = (returnCode) =>
      @bufferedProcess = null

      if (atom.config.get 'psychopy.enableExecTime') is true
        executionTime = (new Date().getTime() - startTime.getTime()) / 1000
        @display 'stdout', '[Finished in '+executionTime.toString()+'s]'

      if returnCode is 0
        @headerView.setStatus 'stop'
      else
        @headerView.setStatus 'err'
      console.log "Exited with #{returnCode}"

    # Run process
    @bufferedProcess = new BufferedProcess({
      command, args, options, stdout, stderr, exit
    })

    @bufferedProcess.onWillThrowError (nodeError) =>
      @bufferedProcess = null
      @output.append $$ ->
        @h1 'Unable to run'
        @pre _.escape command
        @h2 'Is it in your PATH?'
        @pre "PATH: #{_.escape process.env.PATH}"
      nodeError.handle()

  stop: ->
    # Kill existing process if available
    if @bufferedProcess?
      @display 'stdout', '^C'
      @headerView.setStatus 'kill'
      @bufferedProcess.kill()
      @bufferedProcess = null

  display: (css, line) ->
    @results += line

    if atom.config.get('psychopy.escapeConsoleOutput')
      line = _.escape(line)

    line = @ansiFilter.toHtml(line)

    padding = parseInt(@output.css('padding-bottom'))
    scrolledToEnd =
      @psychopy.scrollBottom() == (padding + @output.trueHeight())

    lessThanFull = @output.trueHeight() <= @psychopy.trueHeight()

    @output.append $$ ->
      @pre class: "line #{css}", =>
        @raw line

    if atom.config.get('psychopy.scrollWithOutput')
      if lessThanFull or scrolledToEnd
        @psychopy.scrollTop(@output.trueHeight())

  copyResults: ->
    if @results
      atom.clipboard.write stripAnsi(@results)
