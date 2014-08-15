Domain  = require('../concepts/Domain')

class Linear extends Domain
  priority: -100

  Solver:  require('cassowary')
  Wrapper: require('../concepts/Wrapper')

  # Convert expressions into cassowary objects

  isVariable: (object) ->
    return object instanceof c.Variable

  isConstraint: (object) ->
    return object instanceof c.Constraint

  isExpression: (object) ->
    return object instanceof c.Expression

  constructor: () ->
    @solver = new c.SimplexSolver()
    @solver.autoSolve = false
    c.debug = true
    super

  provide: (result) ->
    @constrain(result)
    return

  # Read commands
  solve: ()->
    Domain::solve.apply(@, arguments)
    if @constrained
      @solver.solve()
    else
      @solver.resolve()
    return @apply(@solver._changed)
  constrain: (constraint) ->
    unless super
      @solver.addConstraint(constraint)

  unconstrain: (constraint) ->
    unless super
      @solver.removeConstraint(constraint)

  undeclare: (variable) ->
    unless super
      if variable.editing
        if cei = @solver._editVarMap.get(variable)
          @solver.removeColumn(cei.editMinus)
          @solver._editVarMap.delete(variable)
      @solver._externalParametricVars.delete(variable)

  edit: (variable, strength, weight, continuation) ->
    constraint = new c.EditConstraint(variable, @strength(strength, 'strong'), @weight(weight))
    @constrain constraint
    variable.editing = constraint
    return constraint

  suggest: (path, value, strength, weight, continuation) ->
    if typeof path == 'string'
      unless variable = @variables[path]
        if continuation
          variable = @declare(path)
          variables = (@variables[continuation] ||= [])
          variables.push(variable)
        else
          return @verify path, value
    else
      variable = path

    unless variable.editing
      @edit(variable, strength, weight, continuation)
    @solver.suggestValue(variable, value)
    return variable

  variable: (name) ->
    return new c.Variable name: name

  stay: ->
    for arg in arguments
      @solver.addStay(arg)
    return


class Linear::Methods extends Domain::Methods
  get: 
    command: (operation, continuation, scope, meta, object, property, path) ->
      if typeof @properties[property] == 'function' && scope
        return @properties[property].call(@, object, object)
      else
        variable = @declare(@getPath(object, property), operation)
      return [variable, path || (property && object) || '']

  strength: (strength, deflt = 'medium') ->
    return strength && c.Strength[strength] || c.Strength[deflt]

  weight: (weight) ->
    return weight

  varexp: (name) ->
    return new c.Expression name: name

  '==': (left, right, strength, weight) ->
    return new c.Equation(left, right, @strength(strength), @weight(weight))

  '<=': (left, right, strength, weight) ->
    return new c.Inequality(left, c.LEQ, right, @strength(strength), @weight(weight))

  '>=': (left, right, strength, weight) ->
    return new c.Inequality(left, c.GEQ, right, @strength(strength), @weight(weight))

  '<': (left, right, strength, weight) ->
    return new c.Inequality(left, c.LEQ, right, @strength(strength), @weight(weight))

  '>': (left, right, strength, weight) ->
    return new c.Inequality(left, c.GEQ, right, @strength(strength), @weight(weight))

  '+': (left, right, strength, weight) ->
    return c.plus(left, right)

  '-': (left, right, strength, weight) ->
    return c.minus(left, right)

  '*': (left, right, strength, weight) ->
    return c.times(left, right)

  '/': (left, right, strength, weight) ->
    return c.divide(left, right)
    
module.exports = Linear