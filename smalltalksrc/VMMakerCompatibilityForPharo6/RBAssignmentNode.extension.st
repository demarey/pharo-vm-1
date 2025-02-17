Extension { #name : 'RBAssignmentNode' }

{ #category : '*VMMakerCompatibilityForPharo6-C translation' }
RBAssignmentNode >> anyReturns: aSequenceOfNodes [
	aSequenceOfNodes do:
		[:node|
		node nodesDo:
			[:n|
			n isReturn ifTrue:
				[^true]]].
	^false
]

{ #category : '*VMMakerCompatibilityForPharo6-C translation' }
RBAssignmentNode >> asTranslatorNodeIn: aTMethod [
	"Answer a TParseNode subclass equivalent of me"
	| varNode valueNode |
	varNode := variable asTranslatorNodeIn: aTMethod.
	valueNode := value asTranslatorNodeIn: aTMethod.
	valueNode isStatementList ifFalse:
		[^TAssignmentNode new
			setVariable: varNode
			expression: valueNode;
			comment: self commentOrNil].
	 "This is a super expansion.  We are in trouble if any statement other than the last is a return."
	(self anyReturns: valueNode statements allButLast) ifTrue:
		[self error: 'haven''t implemented pushing down assignments into other than the last return'].
	"As of 6/25/2012 19:30 superExpansionNodeFor:args: elides the final return."
	self assert: valueNode statements last isReturn not.
	^TStatementListNode statements: valueNode statements allButLast,
					{ TAssignmentNode new
						setVariable: varNode
						expression: valueNode statements last;
						comment: self commentOrNil }
]
