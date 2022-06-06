
#### Mayor Changes:

throw exceptions in If statements replaced with *Runtime.Assert()*
* Beef does not feature exceptions or Throwing
* Some methods may need to be refactored into using *System.Result*


*DEBUG* preprocesor has been changed to *!ECS_DISABLE_DEBUG_CHECKS*

This is done to Match one of Beef's features, the ability to set Optimization levels on a Per-Function/Type level.
It makes more sense to set the Debug checks manually, rather than using a built-in 




