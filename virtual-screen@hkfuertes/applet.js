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
    this._applet_context_menu.toggle();
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
    // Check display state using x11-manager is-connected
    try {
      const [success, stdout] = GLib.spawn_command_line_sync(`${this._path}/bin/x11-manager.sh is-connected`);
      this._displayState = success && stdout.toString().trim() === 'yes';
    } catch (e) {
      this._displayState = false;
    }

    // Check Sunshine state
    try {
      const [success, stdout] = GLib.spawn_command_line_sync(
        `${this._path}/bin/sunshine-manager.sh status`
      );
      this._sunshineState = success && stdout.toString().trim() === 'running';
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
    
    // Refresh after a delay to confirm the change
    GLib.timeout_add(GLib.PRIORITY_DEFAULT, 5000, () => {
      this._refreshState();
      return false;
    });
  }

  _startSunshine() {
    global.log('Virtual Screen: Starting Sunshine');
    // Show notification
    GLib.spawn_command_line_async('notify-send "Virtual Screen" "Starting Sunshine streaming..."');

    // Configure Sunshine with preup/predown scripts
    this._runSunshine('start');
  }

  _stopSunshine() {
    global.log('Virtual Screen: Stopping Sunshine');
    // Show notification
    GLib.spawn_command_line_async('notify-send "Virtual Screen" "Stopping Sunshine streaming..."');

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
    global.log(`Virtual Screen: Executing: ${cmdline}`);
    try {
      const [success, stdout, stderr] = GLib.spawn_command_line_sync(cmdline);
      const out = stdout ? stdout.toString() : '';
      const err = stderr ? stderr.toString() : '';
      global.log(`Virtual Screen: Command result - success: ${success}, stdout: ${out}, stderr: ${err}`);
    } catch (e) {
      global.log(`Virtual Screen: Command failed with exception: ${e}`);
    }
  }
}

function main(metadata, orientation, panel_height, instance_id) {
  return new VirtualScreenApplet(metadata, orientation, panel_height, instance_id);
}
