"
FloatArrayPlugin provides fast access to FloatArrays for batch processing of float numbers
"
Class {
	#name : 'FloatArrayPlugin',
	#superclass : 'InterpreterPlugin',
	#category : 'VMMaker-Plugins',
	#package : 'VMMaker',
	#tag : 'Plugins'
}

{ #category : 'translation to C' }
FloatArrayPlugin class >> declareCVarsIn: cg [
	"Nothing to declare..."
]

{ #category : 'arithmetic primitives' }
FloatArrayPlugin >> primitiveAddFloatArray [
	"Primitive. Add the receiver and the argument, both Float32Arrays and store the result into the receiver."
	| rcvr arg rcvrPtr argPtr length |
	<export: true>
	<var: #rcvrPtr type: #'float *'>
	<var: #argPtr type: #'float *'>
	arg := interpreterProxy stackValue: 0.
	rcvr := interpreterProxy stackValue: 1.
	((interpreterProxy isWords: arg)
	 and: [(interpreterProxy isWords: rcvr)
	 and: [(length := interpreterProxy stSizeOf: arg) = (interpreterProxy stSizeOf: rcvr)]]) ifFalse:
		[^interpreterProxy primitiveFail].
	rcvrPtr := self cCoerce: (interpreterProxy firstIndexableField: rcvr) to: #'float *'.
	argPtr := self cCoerce: (interpreterProxy firstIndexableField: arg) to: #'float *'.
	0 to: length-1 do:[:i|
		rcvrPtr at: i put: (self cCoerce: (rcvrPtr at: i) to: #double) + (self cCoerce: (argPtr at: i) to: #double)].
	interpreterProxy pop: 1. "Leave rcvr on stack"
]

{ #category : 'arithmetic primitives' }
FloatArrayPlugin >> primitiveAddScalar [
	"Primitive. Add the argument, a scalar value to the receiver, a Float32Array"
	| rcvr rcvrPtr value length |
	<export: true>
	<var: #value type: #double>
	<var: #rcvrPtr type:#'float *'>
	value := interpreterProxy stackFloatValue: 0.
	interpreterProxy failed ifTrue:[^nil].
	rcvr := interpreterProxy stackValue: 1.
	(interpreterProxy isWords: rcvr) ifFalse:
		[^interpreterProxy primitiveFail].
	length := interpreterProxy stSizeOf: rcvr.
	rcvrPtr := self cCoerce: (interpreterProxy firstIndexableField: rcvr) to: #'float *'.
	0 to: length-1 do:[:i|
		rcvrPtr at: i put: (self cCoerce: (rcvrPtr at: i) to: #double) + value].
	interpreterProxy pop: 1. "Leave rcvr on stack"
]

{ #category : 'access primitives' }
FloatArrayPlugin >> primitiveAt [
	<export: true>
	| index rcvr floatPtr |
	<var: #floatPtr type: #'float *'>
	index := interpreterProxy stackIntegerValue: 0.
	rcvr := interpreterProxy stackValue: 1.
	(interpreterProxy failed not
	 and: [(interpreterProxy isWords: rcvr)
	 and: [index > 0 and: [index <= (interpreterProxy slotSizeOf: rcvr)]]]) ifFalse:
		[^interpreterProxy primitiveFail].
	floatPtr := self cCoerce: (interpreterProxy firstIndexableField: rcvr) to: #'float *'.
	interpreterProxy methodReturnFloat: (floatPtr at: index - 1)
]

{ #category : 'access primitives' }
FloatArrayPlugin >> primitiveAtPut [

	| value floatValue index rcvr floatPtr |
	<export: true>
	<var: #floatValue type: #double>
	<var: #floatPtr type: #'float *'>
	value := interpreterProxy stackValue: 0.
	floatValue := (interpreterProxy isIntegerObject: value)
					ifTrue: [(interpreterProxy integerValueOf: value) asFloat]
					ifFalse: [interpreterProxy floatValueOf: value].
	index := interpreterProxy stackIntegerValue: 1.
	rcvr := interpreterProxy stackValue: 2.
	(interpreterProxy failed not
	 and: [(interpreterProxy isWords: rcvr)
	 and: [index > 0 and: [index <= (interpreterProxy slotSizeOf: rcvr)]]]) ifFalse:
		[^interpreterProxy primitiveFail].
	floatPtr := self cCoerce: (interpreterProxy firstIndexableField: rcvr) to: #'float *'.
	floatPtr at: index-1 put: (self cCoerce: floatValue to: #float).
	interpreterProxy pop: 3 thenPush: value
]

{ #category : 'arithmetic primitives' }
FloatArrayPlugin >> primitiveDivFloatArray [
	"Primitive. Divide each element in the receiver by the corresponding element in the argument, both FloatArrays, and store the result into the receiver."
	<export: true>
	| rcvr arg rcvrPtr argPtr length |
	<var: #rcvrPtr type: #'float *'>
	<var: #argPtr type: #'float *'>
	arg := interpreterProxy stackValue: 0.
	rcvr := interpreterProxy stackValue: 1.
	((interpreterProxy isWords: arg)
	 and: [(interpreterProxy isWords: rcvr)
	 and: [(length := interpreterProxy stSizeOf: arg) = (interpreterProxy stSizeOf: rcvr)]]) ifFalse:
		[^interpreterProxy primitiveFail].
	rcvrPtr := self cCoerce: (interpreterProxy firstIndexableField: rcvr) to: #'float *'.
	argPtr := self cCoerce: (interpreterProxy firstIndexableField: arg) to: #'float *'.
	"Check if any of the argument's values is zero"
	0 to: length - 1 do:
		[:i| (argPtr at: i) = (self cCoerce: 0.0 to: #float) ifTrue: "i.e. check for both 0.0 and -0.0"
			[^interpreterProxy primitiveFail]].
	0 to: length - 1 do:
		[:i| rcvrPtr at: i put: (self cCoerce: (rcvrPtr at: i) to: #double) / (self cCoerce: (argPtr at: i) to: #double)].
	interpreterProxy pop: 1 "Leave rcvr on stack"
]

{ #category : 'arithmetic primitives' }
FloatArrayPlugin >> primitiveDivScalar [
	"Primitive. Divide each element in the receiver by the argument, a scalar, and store the result into the receiver, a FloatArray"
	| rcvr rcvrPtr value inverse length |
	<export: true>
	<var: #inverse type:'double '>
	<var: #value type: #double>
	<var: #rcvrPtr type:#'float *'>
	value := interpreterProxy stackFloatValue: 0.
	interpreterProxy failed ifTrue:[^nil].
	rcvr := interpreterProxy stackValue: 1.
	(interpreterProxy isWords: rcvr) ifFalse:
		[^interpreterProxy primitiveFail].
	length := interpreterProxy stSizeOf: rcvr.
	rcvrPtr := self cCoerce: (interpreterProxy firstIndexableField: rcvr) to: #'float *'.
	inverse := 1.0 / value.
	0 to: length-1 do:[:i|
		rcvrPtr at: i put: (self cCoerce: (rcvrPtr at: i) to: #double) * inverse.
	].
	interpreterProxy pop: 1 "Leave rcvr on stack"
]

{ #category : 'arithmetic primitives' }
FloatArrayPlugin >> primitiveDotProduct [
	"Primitive. Compute the dot product of the receiver and the argument.
	The dot product is defined as the sum of the products of the individual elements."
	<export: true>
	| rcvr arg rcvrPtr argPtr length result |
	<var: #result type: #double>
	<var: #rcvrPtr type: #'float *'>
	<var: #argPtr type: #'float *'>
	arg := interpreterProxy stackValue: 0.
	rcvr := interpreterProxy stackValue: 1.
	((interpreterProxy isWords: arg)
	 and: [(interpreterProxy isWords: rcvr)
	 and: [(length := interpreterProxy stSizeOf: arg) = (interpreterProxy stSizeOf: rcvr)]]) ifFalse:
		[^interpreterProxy primitiveFail].
	rcvrPtr := self cCoerce: (interpreterProxy firstIndexableField: rcvr) to: #'float *'.
	argPtr := self cCoerce: (interpreterProxy firstIndexableField: arg) to: #'float *'.
	result := 0.0.
	0 to: length-1 do:[:i|
		result := result + ((self cCoerce: (rcvrPtr at: i) to: #double) * (self cCoerce: (argPtr at: i) to: #double)).
	].
	interpreterProxy methodReturnFloat: result. "Return result"
]

{ #category : 'access primitives' }
FloatArrayPlugin >> primitiveEqual [

	| rcvr arg rcvrPtr argPtr length |
	<export: true>
	<var: #rcvrPtr type: #'float *'>
	<var: #argPtr type: #'float *'>
	arg := interpreterProxy stackValue: 0.
	rcvr := interpreterProxy stackValue: 1.
	((interpreterProxy isWords: arg)
	 and: [(interpreterProxy isWords: rcvr)]) ifFalse:
		[^interpreterProxy primitiveFail].
	interpreterProxy pop: 2.
	(length := interpreterProxy stSizeOf: arg) = (interpreterProxy stSizeOf: rcvr) ifFalse:
		[^interpreterProxy pushBool: false].
	rcvrPtr := self cCoerce: (interpreterProxy firstIndexableField: rcvr) to: #'float *'.
	argPtr := self cCoerce: (interpreterProxy firstIndexableField: arg) to: #'float *'.
	0 to: length-1 do:[:i|
		(rcvrPtr at: i) = (argPtr at: i) ifFalse:[^interpreterProxy pushBool: false].
	].
	^interpreterProxy pushBool: true
]

{ #category : 'access primitives' }
FloatArrayPlugin >> primitiveHashArray [

	| rcvr rcvrPtr length result |
	<export: true>
	<var: #rcvrPtr type: #'int *'>
	rcvr := interpreterProxy stackValue: 0.
	(interpreterProxy isWords: rcvr) ifFalse:
		[^interpreterProxy primitiveFail].
	length := interpreterProxy stSizeOf: rcvr.
	rcvrPtr := self cCoerce: (interpreterProxy firstIndexableField: rcvr) to: #'int *'.
	result := 0.
	0 to: length-1 do:[:i|
		result := result + (rcvrPtr at: i).
	].
	interpreterProxy methodReturnInteger: (result bitAnd: 16r1FFFFFFF)
]

{ #category : 'arithmetic primitives' }
FloatArrayPlugin >> primitiveLength [
	"Primitive. Compute the length of the argument (sqrt of sum of component squares)."
	<export: true>
	| rcvr rcvrPtr length len |
	<var: #rcvrPtr type: #'float *'>
	<var: #len type: #double>
	rcvr := interpreterProxy stackValue: 0.
	(interpreterProxy isWords: rcvr) ifFalse:
		[^interpreterProxy primitiveFailFor: PrimErrBadReceiver].
	length := interpreterProxy stSizeOf: rcvr.
	rcvrPtr := self cCoerce: (interpreterProxy firstIndexableField: rcvr) to: #'float *'.
	len := 0.0.
	0 to: length-1 do:
		[:i| len := len + ((self cCoerce: (rcvrPtr at: i) to: #double) * (self cCoerce: (rcvrPtr at: i) to: #double)) ].
	len > 0.0 ifFalse:
		[^interpreterProxy primitiveFailFor: PrimErrBadReceiver].
	interpreterProxy methodReturnFloat: (self sqrt: len)
]

{ #category : 'arithmetic primitives' }
FloatArrayPlugin >> primitiveMulFloatArray [
	"Primitive. Multiply the receiver and the argument, both FloatArrays and store the result into the receiver."
	<export: true>
	| rcvr arg rcvrPtr argPtr length |
	<var: #rcvrPtr type: #'float *'>
	<var: #argPtr type: #'float *'>
	arg := interpreterProxy stackValue: 0.
	rcvr := interpreterProxy stackValue: 1.
	((interpreterProxy isWords: arg)
	 and: [(interpreterProxy isWords: rcvr)
	 and: [(length := interpreterProxy stSizeOf: arg) = (interpreterProxy stSizeOf: rcvr)]]) ifFalse:
		[^interpreterProxy primitiveFail].
	rcvrPtr := self cCoerce: (interpreterProxy firstIndexableField: rcvr) to: #'float *'.
	argPtr := self cCoerce: (interpreterProxy firstIndexableField: arg) to: #'float *'.
	0 to: length-1 do:[:i|
		rcvrPtr at: i put: (self cCoerce: (rcvrPtr at: i) to: #double) * (self cCoerce: (argPtr at: i) to: #double).
	].
	interpreterProxy pop: 1 "Leave rcvr on stack"
]

{ #category : 'arithmetic primitives' }
FloatArrayPlugin >> primitiveMulScalar [
	<export: true>
	"Primitive. Multiply elements in the receiver, a FloatArray, by argument, a scalar value, and store the result into the receiver."
	| rcvr rcvrPtr value length |
	<var: #value type: #double>
	<var: #rcvrPtr type:#'float *'>
	value := interpreterProxy stackFloatValue: 0.
	interpreterProxy failed ifTrue:[^nil].
	rcvr := interpreterProxy stackValue: 1.
	(interpreterProxy isWords: rcvr) ifFalse:
		[^interpreterProxy primitiveFail].
	length := interpreterProxy stSizeOf: rcvr.
	rcvrPtr := self cCoerce: (interpreterProxy firstIndexableField: rcvr) to: #'float *'.
	0 to: length-1 do:[:i|
		rcvrPtr at: i put: (self cCoerce: (rcvrPtr at: i) to: #double) * value.
	].
	interpreterProxy pop: 1 "Leave rcvr on stack"
]

{ #category : 'arithmetic primitives' }
FloatArrayPlugin >> primitiveNormalize [
	"Primitive. Normalize the argument (A FloatArray) in place."
	<export: true>
	| rcvr rcvrPtr length len |
	<var: #rcvrPtr type: #'float *'>
	<var: #len type: #double>
	rcvr := interpreterProxy stackValue: 0.
	(interpreterProxy isWords: rcvr) ifFalse:
		[^interpreterProxy primitiveFailFor: PrimErrBadReceiver].
	length := interpreterProxy stSizeOf: rcvr.
	rcvrPtr := self cCoerce: (interpreterProxy firstIndexableField: rcvr) to: #'float *'.
	len := 0.0.
	0 to: length - 1 do:
		[:i| len := len + ((self cCoerce: (rcvrPtr at: i) to: #double) * (self cCoerce: (rcvrPtr at: i) to: #double)) ].
	len > 0.0 ifFalse:
		[^interpreterProxy primitiveFailFor: PrimErrBadReceiver].

	len := self sqrt: len.
	0 to: length - 1 do:
		[:i| rcvrPtr at: i put: ((self cCoerce: (rcvrPtr at: i) to: #double) / len) ].

	"Leave receiver on the stack."
]

{ #category : 'arithmetic primitives' }
FloatArrayPlugin >> primitiveSubFloatArray [
	"Primitive. Subtract each element in the argument from each element in the receiver, both FloatArrays and store the result into the receiver."
	<export: true>
	| rcvr arg rcvrPtr argPtr length |
	<var: #rcvrPtr type: #'float *'>
	<var: #argPtr type: #'float *'>
	arg := interpreterProxy stackValue: 0.
	rcvr := interpreterProxy stackValue: 1.
	((interpreterProxy isWords: arg)
	 and: [(interpreterProxy isWords: rcvr)
	 and: [(length := interpreterProxy stSizeOf: arg) = (interpreterProxy stSizeOf: rcvr)]]) ifFalse:
		[^interpreterProxy primitiveFail].
	rcvrPtr := self cCoerce: (interpreterProxy firstIndexableField: rcvr) to: #'float *'.
	argPtr := self cCoerce: (interpreterProxy firstIndexableField: arg) to: #'float *'.
	0 to: length-1 do:[:i|
		rcvrPtr at: i put: (self cCoerce: (rcvrPtr at: i) to: #double) - (self cCoerce: (argPtr at: i) to: #double).
	].
	interpreterProxy pop: 1 "Leave rcvr on stack"
]

{ #category : 'arithmetic primitives' }
FloatArrayPlugin >> primitiveSubScalar [
	"Primitive. Subtract the argument, a scalar value from  each element in the receiver, a FloatArray"
	<export: true>
	| rcvr rcvrPtr value length |
	<var: #value type: #double>
	<var: #rcvrPtr type:#'float *'>
	value := interpreterProxy stackFloatValue: 0.
	interpreterProxy failed ifTrue:[^nil].
	rcvr := interpreterProxy stackValue: 1.
	(interpreterProxy isWords: rcvr) ifFalse:
		[^interpreterProxy primitiveFail].
	length := interpreterProxy stSizeOf: rcvr.
	rcvrPtr := self cCoerce: (interpreterProxy firstIndexableField: rcvr) to: #'float *'.
	0 to: length-1 do:[:i|
		rcvrPtr at: i put: (self cCoerce: (rcvrPtr at: i) to: #double) - value.
	].
	interpreterProxy pop: 1 "Leave rcvr on stack"
]

{ #category : 'arithmetic primitives' }
FloatArrayPlugin >> primitiveSum [
	"Primitive. Answer the sum of each float in the receiver, a FloatArray."
	<export: true>
	| rcvr rcvrPtr length sum |
	<var: #sum type: #double>
	<var: #rcvrPtr type: #'float *'>
	rcvr := interpreterProxy stackValue: 0.
	(interpreterProxy isWords: rcvr) ifFalse:
		[^interpreterProxy primitiveFail].
	length := interpreterProxy stSizeOf: rcvr.
	rcvrPtr := self cCoerce: (interpreterProxy firstIndexableField: rcvr) to: #'float *'.
	sum := 0.0.
	0 to: length-1 do:[:i|
		sum := sum + (self cCoerce: (rcvrPtr at: i) to: #double).
	].
	interpreterProxy methodReturnFloat: sum
]

{ #category : 'simulation' }
FloatArrayPlugin >> sqrt: aFloat [
	<doNotGenerate>
	^aFloat sqrt
]
