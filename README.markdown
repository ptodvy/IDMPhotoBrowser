# IDMPhotoBrowser

IDMPhotoBrowser é uma modificação da biblioteca [MWPhotoBrowser](https://github.com/mwaterfall/MWPhotoBrowser).

O MWPhotoBrowser é muito bom, porém poderia ser melhor. Há algum tempo o código não é atualizado e há uma notável necessidade de um update.

O IDMPhotoBrowser é desenvolvida com base nos recursos do visualizador de fotos do app do Facebook.

[SCREENSHOTS]

### Mudanças do projeto da MWPhotoBrowser

- Atualizado pra ARC
- Uso da AFNetworking pra carregar as imagem


## Features

- Can display one or more images by providing either `UIImage` objects, file paths to images on the device, or URLs to images online
- Handles the downloading and caching of photos from the web seamlessly
- Photos can be zoomed and panned, and optional captions can be displayed

### New features

- Gestos do app do facebook, como dismiss photo with vertical swipe
- Progresso do download de cada foto
- Carregar fotos sem precisar de delegate
- Ações customizadas
- Opção de remoção das setas pra passar as fotos


## Usage

See the code snippet below for an example of how to implement the photo browser.

    NSArray *photosURL = @[[NSURL URLWithString:@"http://farm4.static.flickr.com/3567/3523321514_371d9ac42f_b.jpg"], [NSURL URLWithString:@"http://farm4.static.flickr.com/3629/3339128908_7aecabc34b_b.jpg"], [NSURL URLWithString:@"http://farm4.static.flickr.com/3364/3338617424_7ff836d55f_b.jpg"], [NSURL URLWithString:@"http://farm4.static.flickr.com/3590/3329114220_5fbc5bc92b_b.jpg"]];
    
    NSMutableArray *photos = [[NSMutableArray alloc] init]; // Create array of 'IDMPhoto' objects
    
    for (NSURL *url in photosURL) {
    	IDMPhoto *photo = [IDMPhoto photoWithURL:url];
    	[photos addObject:photo];
    }
    
    IDMPhotoBrowser *browser = [[IDMPhotoBrowser alloc] initWithPhotos:photos]; // init with the IDMPhoto's array
    browser.delegate = self;
    browser.displayActionButton = YES;
    browser.actionButtonTitles = [[NSMutableArray alloc] initWithObjects:@"action1", @"action2", nil]; // If you want to use your own actions, alloc and set the titles. And don't forget to set the delegate = self, and create the method photoBrowser:actionIndex:
	browser.displayArrowButton = YES;
    browser.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    
    self.modalPresentationStyle = self.navigationController.modalPresentationStyle = self.tabBarController.modalPresentationStyle = UIModalPresentationCurrentContext;
    [self presentModalViewController:browser animated:YES];


### Photo Captions

Photo captions can be displayed simply by setting the `caption` property on specific photos:

    IDMPhoto *photo = [IDMPhoto photoWithFilePath:[[NSBundle mainBundle] pathForResource:@"photo2l" ofType:@"jpg"]];
    photo.caption = @"Campervan";

No caption will be displayed if the caption property is not set.

#### Custom Captions

By default, the caption is a simple black transparent view with a label displaying the photo's caption in white. If you want to implement your own caption view, follow these steps:

1. Optionally use a subclass of `IDMPhoto` for your photos so you can store more data than a simple caption string.
2. Subclass `IDMCaptionView` and override `-setupCaption` and `-sizeThatFits:` (and any other UIView methods you see fit) to layout your own view and set it's size. More information on this can be found in `IDMCaptionView.h`
3. Implement the `-photoBrowser:captionViewForPhotoAtIndex:` IDMPhotoBrowser delegate method (shown below).

Example delegate method for custom caption view:

    - (IDMCaptionView *)photoBrowser:(IDMPhotoBrowser *)photoBrowser captionViewForPhotoAtIndex:(NSUInteger)index {
        IDMPhoto *photo = [self.photos objectAtIndex:index];
        MyIDMCaptionViewSubclass *captionView = [[MyIDMCaptionViewSubclass alloc] initWithPhoto:photo];
        return [captionView autorelease];
    }


## Adding to your project

### Using CocoaPods

[...]

### Including Source Directly Into Your Project

Simply add the files inside `IDMPhotoBrowser/IDMPhotoBrowser` to your Xcode project, copying them to your project's directory if required.


## Outstanding issues and improvements

[...]

## Notes and Accreditation

### Opensource libraries used

- [AFNetWorking](https://github.com/AFNetworking/AFNetworking)
- [DACircularProgress](https://github.com/danielamitay/DACircularProgress)
- [SVProgressHUD](https://github.com/samvermette/SVProgressHUD)

Demo photos kindly provided by Oliver Waters (<http://twitter.com/oliverwaters>).


## Licence

[...]