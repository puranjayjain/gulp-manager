ViewElement = require('./view-element')
GulpfileRunner = require('../../gulpfile-runner')
GulpfileUtil = require('../../gulpfile-util')
Converter = require 'ansi-to-html'
{Emitter, CompositeDisposable} = require('atom')
$ = require('jquery')

class OutputView extends ViewElement
  prepare: (@gulpfile, id, @active) ->
    super(id, @active)
    @type = 'Output'

    @subscriptions = new CompositeDisposable()
    @gulpfileUtil = new GulpfileUtil()
    @converter = new Converter()
    @emitter = new Emitter()

    @filePath = @gulpfileUtil.createFilePath(@gulpfile.dir, @gulpfile.fileName)
    @gulpfileRunner = new GulpfileRunner(@filePath)

    @addTaskContainer()
    @addOutputContainer()

    @subscriptions.add @onTaskClicked(@runTask.bind(@))

    if @active
      @addGulpTasks()

    return @

  onTaskClicked: (callback) ->
    return @emitter.on('task:clicked', callback)

  addOutputContainer: ->
    if @outputContainer
      @.removeChild(@outputContainer)

    @outputContainer = document.createElement('div')
    @outputContainer.className = 'output-container'

    @appendChild(@outputContainer)

  addTaskContainer: ->
    if @taskContainer
      @.removeChild(@taskContainer)

    @taskContainer = document.createElement('div')
    @taskContainer.className = 'task-container'

    @appendChild(@taskContainer)

  setVisibility: (value) ->
    super(value)

  addGulpTasks: ->
    @tasks = []
    output = "fetching gulp tasks for #{@filePath}"
    output += " with args: #{@gulpfile.args}" if @gulpfile.args
    @writeOutput(output, 'text-info')

    $(@taskContainer).empty()

    onTaskOutput = (output) =>
      for task in output.split('\n') when task.length
        @tasks.push(task)

    onTaskExit = (code) =>
      if code is 0

        @taskContainer.appendChild(@createTaskList(@tasks))
        @taskContainer.appendChild(@createCustomTaskContainer())

        @writeOutput("#{@tasks.length} tasks found", "text-info")
      else
        @onExit(code)

    @gulpfileRunner.getGulpTasks(onTaskOutput.bind(@),
      @onError.bind(@), onTaskExit.bind(@), @gulpfile.args)

  createTaskList: (tasks) ->
    taskListContainer = document.createElement('div')
    taskListContainer.classList.add('task-list-container')
    taskList = document.createElement('ul')
    for task in @tasks.sort()
      listItem = document.createElement('li')
      $(listItem).append("<span class='icon icon-zap'>#{task}</span>")

      do (task, @emitter) -> listItem.firstChild.addEventListener('click', ->
        emitter.emit('task:clicked', task)
      )

      taskList.appendChild(listItem)

    taskListContainer.appendChild(taskList)

    return taskListContainer

  createCustomTaskContainer: ->

    customTaskContainer = document.createElement('div')
    customTaskContainer.classList.add('custom-task-container')
    customTaskLabel = document.createElement('span')
    customTaskLabel.className = 'inline-block'
    customTaskLabel.textContent =  "Custom Task:"
    customTaskInput = document.createElement('atom-text-editor')
    customTaskInput.setAttribute('mini', '')
    customTaskInput.getModel().setPlaceholderText('Press Enter to run')

    customTaskInput.addEventListener('keyup', (e) =>
      #Run if user presses enter
      @runTask(customTaskInput.getModel().getText()) if e.keyCode == 13
    )

    customTaskContainer.appendChild(customTaskLabel)
    customTaskContainer.appendChild(customTaskInput)

    return customTaskContainer

  runTask: (task) ->
    @gulpfileRunner.runGulp(task,
      @onOutput.bind(@), @onError.bind(@), @onExit.bind(@))

  writeOutput: (line, klass) ->
    if line and line.length

      el = document.createElement('pre')
      $(el).append(line)
      if klass
        el.className = klass
      @outputContainer.appendChild(el)
      $(@outputContainer).scrollTop(@outputContainer.scrollHeight)

  onOutput: (output) ->
    for line in output.split('\n')
      @writeOutput(@converter.toHtml(line))

  onError: (output) ->
    for line in output.split('\n')
      @writeOutput(@converter.toHtml(line), 'text-error')

  onExit: (code) ->
    @writeOutput("Exited with code #{code}",
      "#{if code then 'text-error' else 'text-success'}")

  refresh: ->
    @destroy()
    @addTaskContainer()
    @addOutputContainer()

    @subscriptions.add @onTaskClicked(@runTask.bind(@))

    if @active
      @addGulpTasks()

  destroy: ->
    @gulpfileRunner.destroy()
    @subscriptions.dispose()


module.exports = document.registerElement('output-view', {
  prototype: OutputView.prototype
})
