const Applet = imports.ui.applet;
const PopupMenu = imports.ui.popupMenu;
const GLib = imports.gi.GLib;

class VirtualScreenApplet extends Applet.IconApplet {
  constructor(metadata, orientation, panel_height, instance_id) {
    super(orientation, panel_height, instance_id);

    this._path = metadata.path;
    this._displayState = false;
    this._sunshineState = false;

    this.set_applet_icon_name('preferences-desktop-display');
    this.set_applet_tooltip('Virtual Screen Manager');

    this._items = {};
    this._buildMenu();
    this._refreshState();
  }

  /* Click izquierdo = abrir menú */
  on_applet_clicked() {
    this._refreshState();
  }

  /* ---------------- Menu ---------------- */

  _buildMenu() {
    const menu = this._applet_context_menu;
    menu.removeAll();

    // Display toggle button
    this._items.displayToggle = new PopupMenu.PopupSwitchMenuItem('Virtual Display', this._displayState);
    this._items.displayToggle.connect('toggled', (state) => this._toggleDisplay(state));
    menu.addMenuItem(this._items.displayToggle);

    menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());

    // Sunshine toggle button
    this._items.sunshineToggle = new PopupMenu.PopupSwitchMenuItem('Sunshine Streaming', this._sunshineState);
    this._items.sunshineToggle.connect('toggled', (state) => this._toggleSunshine(state));
    menu.addMenuItem(this._items.sunshineToggle);
  }

  /* ---------------- State Management ---------------- */

  _refreshState() {
    // Check display state - look for HDMI-1 in xrandr output
    try {
      const [success, stdout] = GLib.spawn_command_line_sync('xrandr');
      this._displayState = success && stdout.toString().includes('HDMI-1 connected');
    } catch (e) {
      this._displayState = false;
    }

    // Check Sunshine state
    try {
      const [success, stdout] = GLib.spawn_command_line_sync(
        'systemctl --user is-active sunshine'
      );
      this._sunshineState = success && stdout.toString().trim() === 'active';
    } catch (e) {
      this._sunshineState = false;
    }

    // Update menu items
    if (this._items.displayToggle) {
      this._items.displayToggle.setToggleState(this._displayState);
    }
    if (this._items.sunshineToggle) {
      this._items.sunshineToggle.setToggleState(this._sunshineState);
    }

    // Update tooltip
    const displayText = this._displayState ? 'Display ON' : 'Display OFF';
    const sunshineText = this._sunshineState ? 'Sunshine ON' : 'Sunshine OFF';
    this.set_applet_tooltip(`Virtual Screen: ${displayText}, ${sunshineText}`);
  }

  /* ---------------- Display Management ---------------- */

  _toggleDisplay(state) {
    const cmd = state ? 'on' : 'off';
    this._runX11(cmd);
    
    // Update state immediately for better UX
    this._displayState = state;
    
    // Refresh after a short delay to confirm the change
    GLib.timeout_add(GLib.PRIORITY_DEFAULT, 1000, () => {
      this._refreshState();
      return false;
    });
  }

  /* ---------------- Sunshine Management ---------------- */

  _toggleSunshine(state) {
    if (state) {
      this._startSunshine();
    } else {
      this._stopSunshine();
    }
    
    // Update state immediately for better UX
    this._sunshineState = state;
    
    // Refresh after a short delay to confirm the change
    GLib.timeout_add(GLib.PRIORITY_DEFAULT, 2000, () => {
      this._refreshState();
      return false;
    });
  }

  _startSunshine() {
    // Configure Sunshine with preup/predown scripts
    this._runSunshine('start');
  }

  _stopSunshine() {
    // Stop Sunshine and restore configuration
    this._runSunshine('stop');
  }

  /* ---------------- Script runners ---------------- */

  _x11Script() {
    return `${this._path}/bin/x11-manager.sh`;
  }

  _sunshineScript() {
    return `${this._path}/bin/sunshine-manager.sh`;
  }

  _runX11(cmd, args = []) {
    const q = s => `"${String(s).replace(/["\\$`]/g, '\\$&')}"`;
    const cmdline = [q(this._x11Script()), q(cmd), ...args.map(q)].join(' ');
    GLib.spawn_command_line_async(cmdline);
  }

  _runSunshine(cmd, args = []) {
    const q = s => `"${String(s).replace(/["\\$`]/g, '\\$&')}"`;
    const cmdline = [q(this._sunshineScript()), q(cmd), ...args.map(q)].join(' ');
    GLib.spawn_command_line_async(cmdline);
  }
}

function main(metadata, orientation, panel_height, instance_id) {
  return new VirtualScreenApplet(metadata, orientation, panel_height, instance_id);
}
