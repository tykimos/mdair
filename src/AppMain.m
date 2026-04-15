#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

// Reuse the markdown renderer from GeneratePreview.m
extern NSString *markdownToHTML(NSString *markdown);
extern NSString *getCSS(void);

// ---------------------------------------------------------------------------
// App Delegate
// ---------------------------------------------------------------------------
@interface MdairAppDelegate : NSObject <NSApplicationDelegate, WKNavigationDelegate>
@property (strong) NSMutableArray<NSWindow *> *windows;
- (IBAction)zoomIn:(id)sender;
- (IBAction)zoomOut:(id)sender;
- (IBAction)actualSize:(id)sender;
@end

@implementation MdairAppDelegate

- (instancetype)init {
    self = [super init];
    if (self) _windows = [NSMutableArray array];
    return self;
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    // If no file was opened via double-click, show a welcome window
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        if (self.windows.count == 0) {
            [self openMarkdownString:@"# mdair\n\nMarkdown QuickLook Previewer.\n\nDrag a `.md` file onto this app or use **Open With** in Finder."
                           withTitle:@"mdair"];
        }
    });
}

- (BOOL)application:(NSApplication *)sender openFile:(NSString *)filename {
    [self openMarkdownFile:filename];
    return YES;
}

- (void)application:(NSApplication *)sender openFiles:(NSArray<NSString *> *)filenames {
    for (NSString *file in filenames) {
        [self openMarkdownFile:file];
    }
    [sender replyToOpenOrPrint:NSApplicationDelegateReplySuccess];
}

- (void)openMarkdownFile:(NSString *)path {
    NSError *error = nil;
    NSString *markdown = [NSString stringWithContentsOfFile:path
                                                  encoding:NSUTF8StringEncoding
                                                     error:&error];
    if (!markdown) {
        markdown = [NSString stringWithContentsOfFile:path
                                            encoding:NSISOLatin1StringEncoding
                                               error:&error];
    }
    if (!markdown) {
        NSLog(@"Failed to read: %@", path);
        return;
    }

    NSString *title = [path lastPathComponent];
    [self openMarkdownString:markdown withTitle:title];
}

- (void)openMarkdownString:(NSString *)markdown withTitle:(NSString *)title {
    NSString *body = markdownToHTML(markdown);
    NSString *css = getCSS();
    NSString *html = [NSString stringWithFormat:
        @"<!DOCTYPE html><html><head><meta charset='utf-8'>"
        "<style>%@</style></head><body>%@"
        "<script src='https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.min.js'></script>"
        "<script>mermaid.initialize({startOnLoad:true,theme:'default'});</script>"
        "</body></html>", css, body];

    NSRect frame = NSMakeRect(0, 0, 860, 700);
    NSWindowStyleMask style = NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                              NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable;
    NSWindow *window = [[NSWindow alloc] initWithContentRect:frame
                                                   styleMask:style
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
    [window setTitle:title];
    [window center];

    WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
    WKWebView *webView = [[WKWebView alloc] initWithFrame:frame configuration:config];
    [webView setAllowsMagnification:YES];
    [webView setNavigationDelegate:self];
    [webView loadHTMLString:html baseURL:nil];
    [window setContentView:webView];
    [window makeKeyAndOrderFront:nil];

    [self.windows addObject:window];
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    NSURL *url = navigationAction.request.URL;
    if (navigationAction.navigationType == WKNavigationTypeLinkActivated && url) {
        [[NSWorkspace sharedWorkspace] openURL:url];
        decisionHandler(WKNavigationActionPolicyCancel);
        return;
    }
    decisionHandler(WKNavigationActionPolicyAllow);
}

- (WKWebView *)activeWebView {
    NSWindow *window = [NSApp keyWindow];
    if (window && [window.contentView isKindOfClass:[WKWebView class]]) {
        return (WKWebView *)window.contentView;
    }
    return nil;
}

- (IBAction)zoomIn:(id)sender {
    WKWebView *webView = [self activeWebView];
    if (webView) {
        webView.magnification = MIN(webView.magnification * 1.25, 5.0);
    }
}

- (IBAction)zoomOut:(id)sender {
    WKWebView *webView = [self activeWebView];
    if (webView) {
        webView.magnification = MAX(webView.magnification / 1.25, 0.25);
    }
}

- (IBAction)actualSize:(id)sender {
    WKWebView *webView = [self activeWebView];
    if (webView) {
        webView.magnification = 1.0;
    }
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

@end

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------
int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSApplication *app = [NSApplication sharedApplication];
        [app setActivationPolicy:NSApplicationActivationPolicyRegular];

        // Create menu bar
        NSMenu *menuBar = [[NSMenu alloc] init];
        NSMenuItem *appMenuItem = [[NSMenuItem alloc] init];
        [menuBar addItem:appMenuItem];
        NSMenu *appMenu = [[NSMenu alloc] init];
        [appMenu addItemWithTitle:@"About mdair" action:@selector(orderFrontStandardAboutPanel:) keyEquivalent:@""];
        [appMenu addItem:[NSMenuItem separatorItem]];
        [appMenu addItemWithTitle:@"Quit mdair" action:@selector(terminate:) keyEquivalent:@"q"];
        [appMenuItem setSubmenu:appMenu];

        NSMenuItem *fileMenuItem = [[NSMenuItem alloc] init];
        [menuBar addItem:fileMenuItem];
        NSMenu *fileMenu = [[NSMenu alloc] initWithTitle:@"File"];
        [fileMenu addItemWithTitle:@"Close" action:@selector(performClose:) keyEquivalent:@"w"];
        [fileMenuItem setSubmenu:fileMenu];

        // Edit menu — enables standard Cmd+C/V/X/A/Z keyboard routing to
        // first responder (WKWebView selection copy). Without this, drag
        // selection works but Cmd+C fails because no menu item binds copy:.
        NSMenuItem *editMenuItem = [[NSMenuItem alloc] init];
        [menuBar addItem:editMenuItem];
        NSMenu *editMenu = [[NSMenu alloc] initWithTitle:@"Edit"];
        [editMenu addItemWithTitle:@"Undo" action:@selector(undo:) keyEquivalent:@"z"];
        NSMenuItem *redoItem = [editMenu addItemWithTitle:@"Redo"
                                                   action:@selector(redo:)
                                            keyEquivalent:@"z"];
        [redoItem setKeyEquivalentModifierMask:(NSEventModifierFlagCommand | NSEventModifierFlagShift)];
        [editMenu addItem:[NSMenuItem separatorItem]];
        [editMenu addItemWithTitle:@"Cut" action:@selector(cut:) keyEquivalent:@"x"];
        [editMenu addItemWithTitle:@"Copy" action:@selector(copy:) keyEquivalent:@"c"];
        [editMenu addItemWithTitle:@"Paste" action:@selector(paste:) keyEquivalent:@"v"];
        [editMenu addItem:[NSMenuItem separatorItem]];
        [editMenu addItemWithTitle:@"Select All" action:@selector(selectAll:) keyEquivalent:@"a"];
        [editMenuItem setSubmenu:editMenu];

        NSMenuItem *viewMenuItem = [[NSMenuItem alloc] init];
        [menuBar addItem:viewMenuItem];
        NSMenu *viewMenu = [[NSMenu alloc] initWithTitle:@"View"];
        [viewMenu addItemWithTitle:@"Zoom In" action:@selector(zoomIn:) keyEquivalent:@"+"];
        [viewMenu addItemWithTitle:@"Zoom Out" action:@selector(zoomOut:) keyEquivalent:@"-"];
        [viewMenu addItemWithTitle:@"Actual Size" action:@selector(actualSize:) keyEquivalent:@"0"];
        [viewMenuItem setSubmenu:viewMenu];

        [app setMainMenu:menuBar];

        MdairAppDelegate *delegate = [[MdairAppDelegate alloc] init];
        [app setDelegate:delegate];
        [app activateIgnoringOtherApps:YES];
        [app run];
    }
    return 0;
}
