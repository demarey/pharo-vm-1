Extension { #name : 'RBCascadeNode' }

{ #category : '*VMMakerCompatibilityForPharo6-C translation' }
RBCascadeNode >> asTranslatorNodeIn: aTMethod [
	"Answer a TParseNode subclass equivalent of me."
	^TStatementListNode new
		setArguments: #()
		statements:
			(Array streamContents:
				[:s| | receiverNode |
				receiverNode := messages first receiver asTranslatorNodeIn: aTMethod.
				"don't expand the receiver if it is a send to get an implicit receiver,
				 e.g self interpreter printHex: oop => printHex(oop), /not/ printHex(cascade0,oop)."
				(receiverNode isSend and: [aTMethod definingClass isNonArgumentImplicitReceiverVariableName: receiverNode selector]) ifTrue:
					[receiverNode := TVariableNode new setName: receiverNode selector].
				receiverNode isLeaf ifFalse:
					[| varNode |
					 varNode := aTMethod newCascadeTempFor: receiverNode.
					 s nextPut: (TAssignmentNode new
								setVariable: varNode
								expression: receiverNode).
					receiverNode := varNode].
				messages do:
					[ :msg | s nextPut: ((msg asTranslatorNodeIn: aTMethod) receiver: receiverNode)]]);
		comment: self commentOrNil
]
