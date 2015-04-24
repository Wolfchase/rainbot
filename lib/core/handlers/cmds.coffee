core    = require(__core)
async   = require('async')
defined = core.defined
_       = require('lodash')

class CmdHandler
  constructor: (aliasHandler, commands) ->
    @commands = commands
    @aliasHandler = aliasHandler

  isCommand: (text) ->
    return text.trim().lower().has(defined.MSG_TRIGGER)

  getCommands: (text) ->
    if @aliasHandler.isAliasCmd(text) then return [text.trim()]
    cmds     = []
    lastpipe = 0
    pipe     = 0
    lastnest = 0
    # Magic, caution hot, do not touch!
    while (pipe = text.indexOf('|', lastpipe)) > -1
      esc   = text.indexOf('\\|', lastpipe)
      dpipe = text.indexOf('||', lastpipe)
      if esc + 1 != pipe and dpipe != pipe
        cmd = text.before('|', lastpipe).trim()
        if cmd.trim() then cmds.push(cmd.trim())
        text = text.substring(pipe + 1)
        lastpipe = pipe+1 - (cmd.length)
      else if dpipe and dpipe == pipe
        pipeContRe = /\|(?!\|)/g
        sub = text.substring(lastpipe)
        cutLen = text.indexOf(sub)
        pipeContRe.exec(sub)
        lastpipe = pipeContRe.lastIndex + cutLen
      else if esc and esc+1 == pipe
        lastpipe = esc + 1
        text = text.substring(0, esc) + "|" + text.substring(esc+2)
    if text.trim() then cmds.push(text.trim())
    return cmds

  executeCommand: (commandRaw, responseHandler, done) ->
    if commandRaw.has('!') then commandName = commandRaw.before('!').trim()
    else commandName = commandRaw
    if commandRaw.has('!') then args = commandRaw.after('!')
    console.log(commandName)
    # if !core.WHITELISTED commandName, ar then done({})
    if @aliasHandler.isAlias commandName
      aliasCommands = @getCommands(@aliasHandler.getAlias(commandName))
      @run aliasCommands, responseHandler, (lastCommand) ->
         lastCommand.name = commandName
         lastCommand.wasAlias = true
         return done lastCommand
    else if @commands.has(commandName.trim())
      command = @commands.get(commandName)
      action = command.action args.clean().split(' '), responseHandler, () ->
        command.name = commandName
        console.log 'here'
        return done command

  run: (commands, responseHandler, respond) ->
    commandsProcessed = 0
    results = {}
    self = this
    async.eachSeries commands, ((commandRaw, next) ->
      commandsProcessed++
      nests = commandRaw.match(/\{(.*?)\}/g)
      if nests?.length > 0
        for nest in nests
          nest = nest.replace('{', '').replace('}', '')
          if results[nest]
            commandRaw =
              commandRaw.replace('{'+nest+'}', results[nest].response)
      self.executeCommand(commandRaw, responseHandler, (firedCommand) ->
        commandName = firedCommand.name
        responses = responseHandler.responses
        output = responseHandler.output()
        if responses or output
          results[commandName] = {}
          if output
            results[commandName].response = output
            console.log 'nested ' + commandName + " with " + results[commandName].response
          else
            results[commandName].response = ''
            for response in responses
              results[commandName].response += " " + response.res
              results[commandName].response =
              results[commandName].response.trim()
            console.log 'nested ' + commandName + " with " + results[commandName].response
        if firedCommand.ASAP and !firedCommand.wasAlias
          console.log 'Would have fired immediately'
        if commandsProcessed == commands.length
          console.log 'firing back with ' + firedCommand
          return respond firedCommand
        responseHandler.reset()
        next()
      )
    ), (err) ->
      return respond()

module.exports = CmdHandler
