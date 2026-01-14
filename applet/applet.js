const St = imports.gi.St;
const Main = imports.ui.main;
const PopupMenu = imports.ui.popupMenu;
const GLib = imports.gi.GLib;
const Gio = imports.gi.Gio;

class HDMIApplet extends imports.ui.applet.IconApplet {
  constructor(metadata, orientation, panel_height, instance_id) {
    super(orientation, panel_height, instance_id);
    
    this.set_applet_icon_name('video-display-symbolic');
    this.set_applet_tooltip('HDMI Manager');
    
    // Menu principal
    this.menuManager.addMenu(this._appletMenu);
    
    this._createMenuItems();
  }
  
  _createMenuItems() {
    // ON
    let onItem = new PopupMenu.PopupMenuItem('HDMI ON (2360x1640@60Hz)');
    onItem.connect('activate', () => this._runScript('on'));
    this._appletMenu.addMenuItem(onItem);
    
    // Change (alta resolución)
    let changeItem = new PopupMenu.PopupMenuItem('High Res (2360x1640)');
    changeItem.connect('activate', () => this._runScript('change'));
    this._appletMenu.addMenuItem(changeItem);
    
    // OFF
    let offItem = new PopupMenu.PopupMenuItem('HDMI OFF');
    offItem.connect('activate', () => this._runScript('off'));
    this._appletMenu.addMenuItem(offItem);
    
    // Status
    let statusItem = new PopupMenu.PopupMenuItem('Status');
    statusItem.connect('activate', () => this._runScript('status'));
    this._appletMenu.addMenuItem(statusItem);    
  }
  
  _runScript(cmd) {
    let scriptPath = `${this._path}/bin/x11-manager.sh`;
    GLib.spawn_command_line_async(`"${scriptPath}" ${cmd}`);
  }

}

function main(metadata, orientation, panel_height, instance_id) {
  return new HDMIApplet(metadata, orientation, panel_height, instance_id);
}
