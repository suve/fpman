**fpman: contributing**
----------
First of all, thanks for willing to contribute to this project.
Here are some guidelines for you:

1. No development should be done on the `master` branch - it is reserved for 
stable releases. Keep your work in the `devel` branch, or if you're working
on a particularly massive feature, consider branching from `devel` and 
coding in this new branch.

2. Including `defines.inc` is mandatory.

3. Use spaces for intendation. `in b4 but spaces waste muh precious disk space`

4. When needing integer types, please use `sInt` / `uInt`, unless you 
absolutely require a type of specific width (e.g. RTL functions which
take references to `Word` as params).

5. When writing object code, please use the old Turbo Pascal object model.
That is, `type TXYZ = object`, not `type TXYZ = class`.

6. All custom types must follow the `TType`, `PPointer` convention (except
for generics).

7. When moving code around (e.g. extracting a function to a new unit),
make sure to update the `uses` clause where needed. Ideally, 
every commit should compile.

8. Comments should be written where appropriate. As a rule of thumb, 
if the intent is not clearly visible by just glancing at the code,
there should probably be a line or two of commentary.

9. Don't leave commented out code. _srsly._

10. Please make your commit messages meaningful. 

11. By contributing, you agree for your code to be included 
under the zlib license.
