# Rimba Games 🦧

Four quick jungle mini-games starring **Oren the Orangutan**, set across Borneo: the rainforests of Sarawak and the slopes of Mt Kinabalu.
It's a single `index.html` file with no build step, no assets and no dependencies. All the art is drawn in code.

**Play:** open `index.html` in a browser, or turn on GitHub Pages for this repo (Settings → Pages → deploy from branch, root).

| Game | Animal | How to play |
|---|---|---|
| **Pangolin Fling** | Pangolin (curls into a ball) | Hold to pump Oren's vine swing higher, release to let go. Release angle matters. Fly through hornbills for a boost. |
| **Kinabalu Skate** | Mousedeer, bearded pigs, sun bears, pygmy elephants | Oren skates down Mt Kinabalu. Tap to jump over animals. The soil slowly slows him, and rain-slick granite slabs speed him up. The run ends when he stops. |
| **Proboscis Plunge** | Proboscis monkey (they really do leap into rivers) | Tap to jump (later is higher), hold to tuck and somersault, let go to straighten for a clean entry. Three rhinoceros-hornbill judges score 3 dives. |
| **Hornbill Flight** | Rhinoceros hornbill (Sarawak is the "Land of the Hornbills") | Tap to flap through gaps between hanging fig roots and mossy stumps. Figs are bonus points. A bump ends the run, and the hornbill lands dizzy but unhurt. |

Controls: mouse, touch, or **Space**. **Esc** = menu, **M** = mute, **1–4** pick a game on the menu.
Best scores are saved in the browser.

No animals are harmed. Every animal launches, lands and celebrates safely.

## World high scores (top 20 per game)

Out of the box, the 🏆 board keeps a **top 20 on each player's device**. To share one board with players worldwide, connect a free [Supabase](https://supabase.com) database (about 10 minutes):

1. Create a free Supabase account and a new project. Pick the region closest to most of your players (e.g. Singapore).
2. In the dashboard, open **SQL Editor → New query**, paste the whole of [`supabase/setup.sql`](supabase/setup.sql), and click **Run**.
   **Already set up before Hornbill Flight was added?** Run the latest `setup.sql` again. It's safe to re-run, keeps every existing score, and adds the new game. Until you do, hornbill scores are rejected by the database.
3. Open **Project Settings → API**. Copy the **Project URL** and the **anon public** key.
4. In `index.html`, find these two lines near `HIGH SCORES` and paste your values in:
   ```js
   const SUPABASE_URL = 'https://xxxx.supabase.co';
   const SUPABASE_ANON_KEY = 'eyJ...';
   ```
   The anon key is meant to be public. The database rules only allow reading scores and adding new ones; they can't be edited or deleted.
5. Upload `index.html` to your website. The button on the menu now reads **World High Scores**.

How it works:
- When a player beats their own best, they're asked for a name and country (picked from a list, with their country preselected from their browser language). If they tick "remember me", later bests are sent automatically.
- The board shows each player's best run only. The same name and country count as one player.
- If Supabase can't be reached, the game still works and saves scores on the device.

What the database enforces (tested on PostgreSQL 16):
- Names are 1–16 characters with no HTML, and are checked against a hidden banned-words list, including disguised spellings like "F.u_c K".
- Countries must be valid two-letter codes.
- Scores must be possible: the plunge maxes out at 90, and fling and skate are capped at 20,000 m.
- Each name can submit at most 5 scores per minute.
- Submission times are set by the server and can't be backdated.

**Be aware:** a browser game can't fully stop cheating. Anyone technical can send a fake but plausible score. Check the board now and then and remove bad entries in the SQL editor:
```sql
delete from public.scores where name ilike '%badname%';
insert into public.banned_words(word) values ('newbadword');
```
