"
This class overrides a few methods in CogVMSimulator required for simulation to work on little-endian architectures (such as the x86 family of processors).  To start it up simply use CogVMSimulatorLSB instead of CogVMSimulator (see the class comment there for more details).  For example:

	(CogVMSimulatorLSB new openOn: Smalltalk imageName) test

Note that the image must have been saved at least once on the local architecture, since the compiled VM performs some byte swapping that the simulator cannot cope with.
"
Class {
	#name : 'CogVMSimulatorLSB',
	#superclass : 'CogVMSimulator',
	#category : 'VMMaker-JITSimulation',
	#package : 'VMMaker',
	#tag : 'JITSimulation'
}

{ #category : 'memory access' }
CogVMSimulatorLSB >> byteAt: byteAddress put: byte [
	^objectMemory byteAt: byteAddress put: byte
]

{ #category : 'memory access' }
CogVMSimulatorLSB >> halfWordHighInLong32: long32 [
	"Used by Balloon"

	^ long32 bitAnd: 16rFFFF
]

{ #category : 'memory access' }
CogVMSimulatorLSB >> halfWordLowInLong32: long32 [
	"Used by Balloon"

	^ long32 bitShift: -16
]

{ #category : 'initialization' }
CogVMSimulatorLSB >> nextShortFrom: aStream [
	"Read a 16-bit quantity from the given (binary) stream."
	^aStream nextLittleEndianNumber: 2
]

{ #category : 'memory access' }
CogVMSimulatorLSB >> vmEndianness [
	"return 0 for little endian, 1 for big endian"
	^0
]
