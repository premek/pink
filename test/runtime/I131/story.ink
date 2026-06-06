// inklecate crashes with a stack overflow resolving the ref parameter (infinite
// recursion in ValueAtVariablePointer). Transcript matches Pink's correct output.
~temp scene = 0

->Start(scene)

===Start(ref scene)
~scene++
SCENE {scene}
-> END
