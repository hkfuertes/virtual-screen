const Applet = imports.ui.applet;
const PopupMenu = imports.ui.popupMenu;
const GLib = imports.gi.GLib;

class VirtualScreenApplet extends Applet.IconApplet {
  constructor(metadata, orientation, panel_height, instance_id) {
    super(orientation, panel_height, instance_id);

    this._path = metadata.path;

    this.set_applet_icon_name('preferences-desktop-display');
    this.set_applet_tooltip('Virtual Screen Manager');

    this._items = {};
    this._buildMenu();
  }

  /* Click izquierdo = abrir menú */
  on_applet_clicked() {
    this._refreshState();
  }

  /* ---------------- Menu ---------------- */

  _buildMenu() {
    const menu = this._applet_context_menu;
    menu.removeAll();

    /* HDMI ON */
    this._items.on = new PopupMenu.PopupMenuItem('HDMI ON');
    this._items.on.connect('activate', () => this._run('on'));
    menu.addMenuItem(this._items.on);

    /* HDMI OFF */
    this._items.off = new PopupMenu.PopupMenuItem('HDMI OFF');
    this._items.off.connect('activate', () => this._run('off'));
    menu.addMenuItem(this._items.off);
  }

  /* ---------------- Script runner ---------------- */

  _script() {
    return `${this._path}/bin/x11-manager.sh`;
  }

  _run(cmd, args = []) {
    const q = s => `"${String(s).replace(/["\\$`]/g, '\\$&')}"`;
    const cmdline = [q(this._script()), q(cmd), ...args.map(q)].join(' ');
    GLib.spawn_command_line_async(cmdline);
  }
}

function main(metadata, orientation, panel_height, instance_id) {
  return new VirtualScreenApplet(metadata, orientation, panel_height, instance_id);
}
