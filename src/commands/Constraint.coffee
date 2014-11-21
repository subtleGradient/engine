Command = require('../concepts/Command')

Constraint = Command.extend
  type: 'Constraint'
  
  signature: [
  	left:     ['Variable', 'Number'],
  	right:    ['Variable', 'Number']
  	[
  		strength: ['String']
  		weight:   ['Number']
  	]
  ]

  # Create a hash that represents substituted variables
  toHash: (meta) ->
    hash = ''
    if meta.values
      for property of meta.values
        hash += property
    return hash

  # Shared interface:

  # Find applied constraint by expression ignoring input variables 
  fetch: (engine, operation) ->
    if operations = engine.operations?[operation.hash ||= @toExpression(operation)]
      for signature, constraint of operations
        if engine.constraints?.indexOf(constraint) > -1
          return constraint

  # Register constraints in variables to handle external mutations
  declare: (engine, constraint) ->
    for path, op of constraint.operations[0].variables
      if definition = engine.variables[path]
        constraints = definition.constraints ||= []
        unless constraints[0]?.operations[0]?.parent.values?[path]?
          if constraints.indexOf(constraint) == -1
            constraints.push(constraint)
    return

  # Unregister constraint from variables
  undeclare: (engine, constraint, quick) ->
    for path, op of constraint.operations[0].variables
      if object = engine.variables[path]
        if (i = object.constraints?.indexOf(constraint)) > -1
          object.constraints.splice(i, 1)
          if object.constraints.length == 0
            op.command.undeclare(engine, object, quick)
    return

  # Add constraint by tracker if it wasnt added before
  add: (constraint, engine, operation, continuation) ->
    other = @fetch(engine, operation)

    operations = constraint.operations ||= other?.operations || []
    if operations.indexOf(operation) == -1
      for op, i in operations by -1
        if op.hash == operation.hash && op.parent[0].key == continuation
          operations.splice(i, 1)
          @unwatch engine, op, continuation
      operations.push(operation)

    engine.add continuation, operation

    if other != constraint
      if other
        @undeclare engine, other, true
        @unset engine, other
        other.operations = undefined
      @declare engine, constraint
      @set engine, constraint

    
    return

  # Register constraint in the domain
  set: (engine, constraint) ->
    if (engine.constraints ||= []).indexOf(constraint) == -1
      engine.constraints.push(constraint)
      (engine.constrained ||= []).push(constraint)

  # Unregister constraint in the domain
  unset: (engine, constraint) ->
    if (index = engine.constraints.indexOf(constraint)) > -1
      engine.constraints.splice(index, 1)
    if (index = engine.constrained?.indexOf(constraint)) > -1
      engine.constrained.splice(index, 1)
    else
      if (engine.unconstrained ||= []).indexOf(constraint) == -1
        engine.unconstrained.push(constraint)
    for operation in constraint.operations
      if (path = operation.parent[0].key)?
        @unwatch(engine, operation, path)
    return

  unwatch: (engine, operation, path) ->
    if paths = engine.paths[path]
      if (i = paths.indexOf(operation)) > -1
        paths.splice(i, 1)
        if paths.length == 0
          delete engine.paths[path]
  # Remove constraint from domain by tracker string
  remove: (engine, operation, continuation) ->
    constraint = @fetch(engine, operation)
    operations = constraint.operations
    if (index = operations.indexOf(operation)) > -1
      if operations.length == 1
        @undeclare(engine, constraint)
        @unset(engine, constraint)
      operations.splice(index, 1)

  # Find constraint in the domain for given variable
  find: (engine, variable) ->
    for other in variable.constraints
      if other.operations[0].variables[variable.name].domain == engine
        if engine.constraints.indexOf(other) > -1
          return true

  # Find groups of constraints that dont reference each other
  split: (constraints) ->
    groups = []
    for constraint in constraints
      groupped = undefined
      vars = constraint.operations[0].variables
      
      for group in groups by -1
        for other in group
          others = other.operations[0].variables
          for path of vars
            if others[path]
              if groupped && groupped != group
                groupped.push.apply(groupped, group)
                groups.splice(groups.indexOf(group), 1)
              else
                groupped = group
              break
          if groups.indexOf(group) == -1
            break
      unless groupped
        groups.push(groupped = [])
      groupped.push(constraint)
    return groups

  # Separate independent groups of constraints into multiple domains
  validate: (engine) ->
    groups = @split(engine.constraints).sort (a, b) ->
      al = a.length
      bl = b.length
      return bl - al

    separated = groups.splice(1)
    commands = []
    if separated.length
      shift = 0
      for group, index in separated
        for constraint, index in group
          @unset engine, constraint
          for operation in constraint.operations
            commands.push operation.parent

    if commands?.length
      if commands.length == 1
        commands = commands[0]
      args = arguments
      if args.length == 1
        args = args[0]
      if commands.length == args.length
        equal = true
        for arg, i in args
          if commands.indexOf(arg) == -1
            equal = false
            break
        if equal
          throw new Error 'Trying to separate what was just added. Means loop. '
      return engine.Command.orphanize commands
      
module.exports = Constraint