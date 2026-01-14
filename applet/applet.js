const Applet = imports.ui.applet;
const PopupMenu = imports.ui.popupMenu;
const GLib = imports.gi.GLib;

const resolutions = [
  { width: 2360, height: 1640, rate: 60, name: 'iPad (100%)' },
  { width: 1770, height: 1230, rate: 60, name: 'iPad (75%)' },
  { width: 1180, height: 820, rate: 60, name: 'iPad (50%)' },
  { width: 1920, height: 1080, rate: 60, name: '1080p' },
  { width: 1280, height: 720, rate: 60, name: '720p' }
];

class VirtualScreenApplet extends Applet.IconApplet {
  constructor(metadata, orientation, panel_height, instance_id) {
    super(orientation, panel_height, instance_id);

    this._path = metadata.path;

    this.set_applet_icon_name('preferences-desktop-display');
    this.set_applet_tooltip('Virtual Screen Manager');

    this._buildMenu();
  }

  // Click izquierdo → abrir menú
  on_applet_clicked(event) {
    this._applet_context_menu.toggle();
  }

  _buildMenu() {
    // Limpio por si acaso
    this._applet_context_menu.removeAll();

    let onItem = new PopupMenu.PopupMenuItem('HDMI ON (1080p)');
    onItem.connect('activate', () =>
      this._runScript('on', ['-w', '1920', '-h', '1080', '-r', '60'])
    );
    this._applet_context_menu.addMenuItem(onItem);

    this._applet_context_menu.addMenuItem(
      new PopupMenu.PopupSeparatorMenuItem()
    );

    resolutions.forEach(res => {
      let item = new PopupMenu.PopupMenuItem(
        `${res.width}x${res.height} (${res.name})`
      );
      item.connect('activate', () =>
        this._runScript('change', [
          '-w', res.width,
          '-h', res.height,
          '-r', res.rate
        ])
      );
      this._applet_context_menu.addMenuItem(item);
    });

    this._applet_context_menu.addMenuItem(
      new PopupMenu.PopupSeparatorMenuItem()
    );

    let offItem = new PopupMenu.PopupMenuItem('HDMI OFF');
    offItem.connect('activate', () => this._runScript('off'));
    this._applet_context_menu.addMenuItem(offItem);

    let statusItem = new PopupMenu.PopupMenuItem('Status');
    statusItem.connect('activate', () => this._runScript('status'));
    this._applet_context_menu.addMenuItem(statusItem);
  }

  _runScript(cmd, args = []) {
    const scriptPath = `${this._path}/bin/x11-manager.sh`;

    const q = (s) => `"${String(s).replace(/["\\$`]/g, '\\$&')}"`;
    const cmdline = [q(scriptPath), q(cmd), ...args.map(q)].join(' ');

    GLib.spawn_command_line_async(cmdline);
  }
}

function main(metadata, orientation, panel_height, instance_id) {
  return new VirtualScreenApplet(metadata, orientation, panel_height, instance_id);
}
