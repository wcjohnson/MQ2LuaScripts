--
-- StateMachine.lua
-- (C)2015 Bill Johnson
--
-- Mixin to allow an object to behave like a state machine.
--

local Util = require("Util")
local extend = Util.extend

local debug = function(...) require("MQ2").log(...) end

local StateMachine = {}

function StateMachine:mixInto(obj)
	obj._state = "__init"
	local oldMixin = obj.mixInto
	extend(obj, self)
	obj.mixInto = oldMixin
	return obj
end

function StateMachine:state() return self._state end

function StateMachine:transitionTo(newState)
	if type(newState) ~= "string" then
		error("States must be strings")
	end
	local currentState, func = self._state

	-- Deferred transition to prevent stack overflow.
	if self._nextState then
		debug("deferring transition to ", newState)
		if newState ~= self._deferredState then
			self._deferredState = newState
		end
		return
	end

	-- No transition.
	if currentState == newState then return end
	-- Mark transition as happening
	self._nextState = newState

	-- willTransition phase
	func = self.willTransition
	if func then
		if not func(self, currentState, newState) then return self:_defer() end
	end
	-- willTransitionFrom: called before state transition; if it
	-- returns a falsy value, transition is declined.
	func = self[ ("willTransitionFrom_%s"):format(currentState) ]
	if func then
		if not func(self, currentState, newState) then return self:_defer() end
	end
	-- willTransitionTo: called before state transition, can return
	-- false to abort.
	func = self[ ("willTransitionTo_%s"):format(newState) ]
	if func then
		if not func(self, currentState, newState) then return self:_defer() end
	end

	-- Do transition
	self._state = newState

	-- didTransition phase
	-- didTransitionFrom: called after state transition
	func = self[ ("didTransitionFrom_%s"):format(currentState) ]
	if func then func(self, currentState, newState) end
	-- didTransitionTo: called after state transition.
	func = self[ ("didTransitionTo_%s"):format(newState) ]
	if func then func(self, currentState, newState) end
	func = self.didTransition
	if func then func(self, currentState, newState) end

	-- Clear reentrancy flag
	self._nextState = nil
	return self:_defer()
end

function StateMachine:_defer()
	local dt = self._deferredState
	if dt then
		debug("executing deferred transition to ", dt)
		self._deferredState = nil
		return self:transitionTo(dt)
	end
end

function StateMachine:transitionStep()
	local currentState, nextState = self._state, self._nextState
	if (not nextState) or (nextState == currentState) then return end
end

return StateMachine
