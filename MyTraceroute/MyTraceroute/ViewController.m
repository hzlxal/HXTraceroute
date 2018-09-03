//
//  ViewController.m
//  MyTraceroute
//
//  Created by hzl on 2018/5/27.
//  Copyright © 2018年 hzl. All rights reserved.
//

#import "ViewController.h"
#import "HXTraceroute.h"

@interface ViewController ()

@property (weak, nonatomic) IBOutlet UITextField *ipTextField;

@property (weak, nonatomic) IBOutlet UITextView *resultView;


@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

}



- (IBAction)beginTraceroute:(id)sender {
    NSString *target = self.ipTextField.text;
    self.resultView.text = @"";
    
    [HXTraceroute startTracerouteWithHost:target stepCompletedBlk:^(HXTracerouteRecord *record) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSString *text = [NSString stringWithFormat:@"%@%@\n", self.resultView.text, record];
            self.resultView.text = [text mutableCopy];
        });
    } andAllCompletedBlk:^(NSArray<HXTracerouteRecord *> *result, BOOL succedd) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (succedd) {
                self.resultView.text =  [self.resultView.text stringByAppendingString:@"~成功 ~"];
            } else {
                self.resultView.text =  [self.resultView.text stringByAppendingString:@"~失败~"];
            }
        });
    }];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
