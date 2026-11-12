# My Notepad

A private, offline note-taking app that runs from a single HTML file. No account, no server, no tracking: everything you write stays in your own browser on your own computer.

## Features

- **Sections and notes**: add, rename and delete sections; each note is a title plus one page that saves as you type.
- **Rich text**: ten familiar fonts, sizes, bold/italic/underline, colour, highlight, lists, alignment, line and paragraph spacing.
- **Pictures and screenshots**: paste with Ctrl+V, drag in, or pick a file. Click a picture to resize it.
- **Locked Journal**: one section is encrypted with a password (AES-256, key derived with PBKDF2). Optional backup question for a forgotten password.
- **Home page**: a to-do list and your upcoming events.
- **Calendar and reminders**: type "Meeting at 2pm" to add an event; a reminder appears before it starts and stays until dismissed.
- **Open files as notes**: Markdown (`.md`), HTML and text files are copied in and shown formatted.
- **Themes**: lavender, teal with golden brown, and soft blue, each with a light and a dark mode.
- **Full screen**: hide the side panels and read or write with only the note on screen.
- **Backup**: export everything to one file and import it again.

## Quick start

1. Download this repository (Code > Download ZIP) and unzip it somewhere permanent.
2. Open `index.html` in Microsoft Edge or Google Chrome.

That is all the app needs.

## Use it like a desktop app (Windows)

From the folder, run:

```
powershell -ExecutionPolicy Bypass -File install.ps1
```

This puts a **My Notepad** shortcut on your Desktop that opens the app in its own window through Microsoft Edge.

To also get Windows notifications for calendar reminders, even while the app is closed:

```
powershell -ExecutionPolicy Bypass -File install.ps1 -Reminders
```

This installs a small background helper (`reminder-helper/helper.ps1`) that starts when you sign in. It listens only on `localhost`, refuses requests from websites, and never goes online. The app sends it event titles and times; it shows the notification at the right moment.

To remove the shortcuts and the helper:

```
powershell -ExecutionPolicy Bypass -File uninstall.ps1
```

Do not move or rename the folder after installing; the shortcut and helper point at it. If you need to move it, export a backup first, move it, run `install.ps1` again, and import the backup.

## Where your data lives

- Notes, to-dos, events and settings are stored in the browser's local storage (IndexedDB) for the browser you open the app with. A different browser will not show them.
- Clearing that browser's site data deletes them. Use **Export backup** regularly.
- Journal entries are encrypted on disk and inside backup files.
- If you forget the Journal password and have not set a backup question, the entries cannot be recovered. Anyone who knows the backup answer can open the Journal, so choose it carefully.

## Customising

Everything is in `index.html`:

- Colours: the theme blocks at the top of the `<style>` section.
- Default sections and the font list: `DEFAULT_SECTIONS` and `FONTS` at the top of the script.

## Requirements

- A Chromium-based browser (Edge or Chrome).
- The Desktop shortcut and reminder helper need Windows 10 or 11 with Windows PowerShell 5.1, which is built in.
