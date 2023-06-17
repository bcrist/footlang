# Comments
In Verdi, anything on a line following a double slash token is ignored:
```verdi
// I am a comment
```
This will look very familiar if you have experience with with C++ (or later versions of C) or one of the many languages that take syntax from them.

## Aside: No multi-line comments?
In Verdi, there are no multi-line comments _a la_ C's `/* ... */`.  You may wonder why not, given that there are some advantages to having them:

* You can comment out many lines at once without adding many characters.
* You can add comments internally within a line.

Virtually every modern editor supports some way to toggle comments on a large range with a single command, so the first advantage is of limited utility.
The second can still be useful, but its use can also make code difficult to read, and encourage antipatterns like embedding tool data in such comments.
As long as a language doesn't restrict where line breaks can be placed too much, it's usually nicer to just use line comments and split the code onto multiple lines.

On top of only having a few advantages, having multi-line comments creates a surprising amount of complexity:

* How do single-line comments and multi-line comments interact?
	* Does a single-line comment disable the start of a multi-line comment?
	* Does a single-line comment disable the end of a multi-line comment?
* Can multi-line comments be nested?
	* If so, it's difficult to get good syntax highlighting in a lot of editors, because many use regular expressions to drive syntax highlighting.
	* If not, it's easy to accidentally end a comment early, probably creating syntax errors, but perhaps just silently doing the wrong thing,
* It creates slightly more cognitive load for the programmer.  How do you decide when to use single line comments vs. multi-line comments?
* Lexing cannot be done correctly starting from any arbitrary line, and in most cases the editor will have to scan from the beginning of the file instead of the first visible line.  For very large files, this may slow down some editors.
* When using an editor without syntax highlighting, the programmer has to do a lot of work to know for sure whether what they're seeing has been commented out or not.

Therefore, Verdi chooses the simplest option of using only line comments.
