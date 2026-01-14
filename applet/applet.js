const Applet = imports.ui.applet;
const PopupMenu = imports.ui.popupMenu;
const Util = imports.misc.util;
const Gio = imports.gi.Gio;
const GLib = imports.gi.GLib;
const Main = imports.ui.main;
const Settings = imports.ui.settings;

class VirtualScreenManager extends Applet.IconApplet {
  constructor(metadata, orientation, panelHeight, instanceId) {
    super(orientation, panelHeight, instanceId);

    this._path = metadata.path;
    this.set_applet_icon_name("preferences-desktop-display");
    this.set_applet_tooltip("Virtual Screen Manager");

    this.settings = new Settings.AppletSettings(
      this,
      metadata.uuid,
      instanceId
    );

    this._buildMenu();
  }

  _buildMenu() {
    this.menu.removeAll();

    let onItem = new PopupMenu.PopupMenuItem("HDMI ON");
    onItem.connect("activate", () => {
      this._runScript("hdmi-on.sh");
    });
    this.menu.addMenuItem(onItem);

    let offItem = new PopupMenu.PopupMenuItem("HDMI OFF");
    offItem.connect("activate", () => {
      this._runScript("hdmi-off.sh");
    });
    this.menu.addMenuItem(offItem);

    this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());

    let regenItem = new PopupMenu.PopupMenuItem("Regenerar EDID");
    regenItem.connect("activate", () => {
      this._runRootScript("edid-generate.py");
    });
    this.menu.addMenuItem(regenItem);
  }

  _runScript(scriptName) {
    let script = `${this._path}/scripts/${scriptName}`;
    Util.spawnCommandLine(`bash "${script}"`);
  }

  _runRootScript(scriptName) {
    let script = `${this._path}/scripts/${scriptName}`;
    Util.spawnCommandLine(`pkexec "${script}"`);
  }
}

function main(metadata, orientation, panelHeight, instanceId) {
  return new VirtualScreenManager(metadata, orientation, panelHeight, instanceId);
}
