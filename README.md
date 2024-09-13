# 🃏 pd-solitaire-effect
 
Solitaire game winning effect on Playdate

https://github.com/user-attachments/assets/fddab4f5-5a6d-49f8-b989-a680bb4d27d5

### how to use

How it works: 
- Create a blank transparent image and keep drawing cards on it. Update the display through sprites. You can place sprites at any layer (Zindex).

Configuration required:
- `playdate.graphics.imagetable` containing all cards
- Coordinates of the positions of several decks to be launched

That's it! I think the code is not complicated, feel free to use and modify.

Additional work that may need to be done:
- Add a fade-out animation after interrupting the animation. (can be achieved through `playdate.graphics.image:fadedImage`)
