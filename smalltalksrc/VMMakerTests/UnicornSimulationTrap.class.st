Class {
	#name : 'UnicornSimulationTrap',
	#superclass : 'Object',
	#instVars : [
		'unicornInvalidAccess',
		'simulator'
	],
	#category : 'VMMakerTests-Unicorn',
	#package : 'VMMakerTests',
	#tag : 'Unicorn'
}

{ #category : 'instance creation' }
UnicornSimulationTrap class >> simulator: simulator error: anUnicornInvalidMemoryAccess [

	^ self new
		simulator: simulator;
		unicornInvalidAccess: anUnicornInvalidMemoryAccess;
		yourself
]

{ #category : 'accessing' }
UnicornSimulationTrap >> address [
	
	^ unicornInvalidAccess address
]

{ #category : 'accessing' }
UnicornSimulationTrap >> nextpc [
	
	| instruction |
	instruction := self simulator disassembleCurrentInstruction.
	^ self simulator instructionPointerRegisterValue + instruction size
]

{ #category : 'accessing' }
UnicornSimulationTrap >> registerAccessor [
	
	"Assume this is a read of a value into a register"
	| failingInstruction registerName |
	self assert: self type = #read.
	
	"Get the register were we wanted to read the value into"
	failingInstruction := self simulator disassembleCurrentInstruction.
	registerName := self simulator extractDestinationRegisterFromAssembly: failingInstruction.
	^ (registerName , ':') asSymbol
]

{ #category : 'accessing' }
UnicornSimulationTrap >> simulator [
	
	^ simulator
]

{ #category : 'accessing' }
UnicornSimulationTrap >> simulator: anObject [
	simulator := anObject
]

{ #category : 'accessing' }
UnicornSimulationTrap >> type [
	
	unicornInvalidAccess type = UcMemoryAccessType UC_MEM_WRITE_UNMAPPED
		ifTrue: [ ^ #write ].
	unicornInvalidAccess type = UcMemoryAccessType UC_MEM_READ_UNMAPPED
		ifTrue: [ ^ #read ].
	unicornInvalidAccess type = UcMemoryAccessType UC_MEM_FETCH_UNMAPPED
		ifTrue: [ ^ #jump ].	
	
	self halt
]

{ #category : 'accessing' }
UnicornSimulationTrap >> unicornInvalidAccess: anUnicornInvalidMemoryAccess [ 
	unicornInvalidAccess := anUnicornInvalidMemoryAccess
]

{ #category : 'accessing' }
UnicornSimulationTrap >> writtenValue [
	"This is the value that was tried to be written but failed (if this is a failed write)"
	^ unicornInvalidAccess value
]
