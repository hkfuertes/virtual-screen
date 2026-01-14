const Applet = imports.ui.applet;
const PopupMenu = imports.ui.popupMenu;
const St = imports.gi.St;
const Util = imports.misc.util;
const GLib = imports.gi.GLib;
const Settings = imports.ui.settings;
const Lang = imports.lang;

const UUID = "virtual-screen@hkfuertes";

function VirtualScreenApplet(metadata, orientation, panelHeight, instanceId) {
    this._init(metadata, orientation, panelHeight, instanceId);
}

VirtualScreenApplet.prototype = {
    __proto__: Applet.TextIconApplet.prototype,

    _init: function(metadata, orientation, panelHeight, instanceId) {
        Applet.TextIconApplet.prototype._init.call(this, orientation, panelHeight, instanceId);

        this.set_applet_icon_name("video-display");
        this.set_applet_label("HDMI");
        this.set_applet_tooltip("HDMI-1 Virtual (iPad/Sunshine)");

        // Settings (para presets de resolución)
        this.settings = new Settings.AppletSettings(this, UUID, instanceId);
        this.settings.bindProperty(Settings.BindingDirection.IN, 
            "width", "width", this._onSettingsChanged, null);
        this.settings.bindProperty(Settings.BindingDirection.IN, 
            "height", "height", this._onSettingsChanged, null);
        this.settings.bindProperty(Settings.BindingDirection.IN, 
            "refresh", "refresh", this._onSettingsChanged, null);

        // Valores por defecto
        this.width = 2360;
        this.height = 1640;
        this.refresh = 60;

        // Menu manager
        this.menuManager = new PopupMenu.PopupMenuManager(this);
        this.menu = new Applet.AppletPopupMenu(this, orientation);
        this.menuManager.addMenu(this.menu);

        this._rebuildMenu();
    },

    on_applet_clicked: function() {
        this.menu.toggle();
    },

    _runHdmiCmd: function(action, env = {}) {
        let appletDir = imports.ui.appletManager.appletMeta[UUID].path;
        let script = GLib.build_filenamev([appletDir, "bin", "hdmi-ipad-manager.sh"]);
        
        let envStr = Object.keys(env).map(function(k) { 
            return k + "=" + env[k]; 
        }).join(" ");
        
        let cmd = "bash -lc '" + envStr + " " + script + " " + action + "'";
        Util.spawnCommandLineAsync(cmd);
    },

    _rebuildMenu: function() {
        this.menu.removeAll();

        // Status
        let statusItem = new PopupMenu.PopupMenuItem("Status HDMI-1", {
            reactive: false
        });
        this._runHdmiCmd("status");  // ejecuta y muestra en terminal
        this.menu.addMenuItem(statusItem);

        this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());

        // Create
        let createItem = new PopupMenu.PopupIconMenuItem(
            "Create HDMI-1 (standby)",
            "list-add",
            St.IconType.SYMBOLIC
        );
        createItem.connect('activate', Lang.bind(this, function() {
            this._runHdmiCmd("create");
        }));
        this.menu.addMenuItem(createItem);

        // ON con valores actuales
        let onItem = new PopupMenu.PopupIconMenuItem(
            "ON: " + this.width + "x" + this.height + "@" + this.refresh + "Hz",
            "media-playback-start",
            St.IconType.SYMBOLIC
        );
        onItem.connect('activate', Lang.bind(this, function() {
            this._runHdmiCmd("on", {
                SUNSHINE_APP_WIDTH: this.width,
                SUNSHINE_APP_HEIGHT: this.height,
                SUNSHINE_APP_FPS: this.refresh
            });
        }));
        this.menu.addMenuItem(onItem);

        // OFF
        let offItem = new PopupMenu.PopupIconMenuItem(
            "OFF",
            "media-playback-stop",
            St.IconType.SYMBOLIC
        );
        offItem.connect('activate', Lang.bind(this, function() {
            this._runHdmiCmd("off");
        }));
        this.menu.addMenuItem(offItem);

        this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());

        // Presets comunes (hardcodeados)
        let presets = [
            {name: "iPad Pro (2360x1640@60)", w: 2360, h: 1640, r: 60},
            {name: "Full HD (1920x1080@60)", w: 1920, h: 1080, r: 60},
            {name: "4K (3840x2160@60)", w: 3840, h: 2160, r: 60}
        ];

        presets.forEach(function(preset) {
            let presetItem = new PopupMenu.PopupSubMenuMenuItem(preset.name);
            this.menu.addMenuItem(presetItem);

            let applyItem = new PopupMenu.PopupMenuItem("Aplicar → ON");
            applyItem.connect('activate', Lang.bind(this, function() {
                this.width = preset.w;
                this.height = preset.h;
                this.refresh = preset.r;
                this._runHdmiCmd("on", {
                    SUNSHINE_APP_WIDTH: preset.w,
                    SUNSHINE_APP_HEIGHT: preset.h,
                    SUNSHINE_APP_FPS: preset.r
                });
            }));
            presetItem.menu.addMenuItem(applyItem);
        }, this);

        this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());
    },

    _onSettingsChanged: function() {
        this._rebuildMenu();
    }
};

function main(metadata, orientation, panelHeight, instanceId) {
    return new VirtualScreenApplet(metadata, orientation, panelHeight, instanceId);
}
