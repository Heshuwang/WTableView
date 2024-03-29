
//
//  WTableView.m
//  WTableView
//
//  Created by hs on 2018/10/22.
//  Copyright © 2018年 . All rights reserved.
//

#define TICK   NSDate *startTime = [NSDate date];

#define TOCK   NSLog(@"Time: %f", -[startTime timeIntervalSinceNow]);

#import "WTableView.h"
#import <objc/runtime.h>
@interface WTableView()<UITableViewDelegate,UITableViewDataSource>

@property (nonatomic, assign) BOOL scrolAnimal;                      //滚动有动画

@property (nonatomic, assign) BOOL cellKVC ;                         //cell 是否是kvc写法

@property (nonatomic, assign) BOOL config ;                          //tableview开启默认配置

@property (nonatomic, strong) UIView *parentView;                    //parentView

@property (nonatomic, strong) NSMutableArray *dataArr;               //dataArr 深拷贝

@property (nonatomic, strong) NSMutableArray *simpleDataArr;         //dataArr 普通赋值

@property (nonatomic, assign) BOOL isSection;                        //section

@property (nonatomic,   copy) WCellCallBlock cellBlock;            //cell block

@property (nonatomic,   copy) WSelectCallBlock selectBlock;        //cell 点击block

@property (nonatomic,   copy) WCellHeight cellHeightBlock;         //cell高度

@property (nonatomic,   copy) WCellCount cellCountBlock;           //cell数量

@property (nonatomic, copy)   WCellHeadHeight headHeightBlock;     //cell头部高度

@property (nonatomic, copy)   WCellFootHeight footHeightBlock;     //cell底部高度

@property (nonatomic, copy)   WCellHeadView headViewBlock;         //cell头部视图

@property (nonatomic, copy)   WCellFootView footViewBlock;         //cell底部视图

@property(nonatomic,weak) id <WTableViewDelegate> Wdelegate;     //代理方法

@property(nonatomic,strong) NSMutableArray *cellNameArr;             //注册的cell

@property(nonatomic,strong) NSMutableArray *pushData;                //传过来的数据

@end
@implementation WTableView

/*
 * 初始化
 */
WTableView * GroupTableView(void){
    
    return  [WTableView shareGroup];
}

/*
 * 初始化
 */
WTableView * PlainTableView(void){
     return  [WTableView sharePlain];
}

+(instancetype)shareGroup{
    WTableView * tableView = [[WTableView alloc]initWithFrame:CGRectZero style:UITableViewStyleGrouped];
    return tableView;
}

+(instancetype)sharePlain{
    WTableView *tableView = [[WTableView alloc]initWithFrame:CGRectZero style:UITableViewStylePlain];
    return tableView;
}

/*
 * 代理和dataSource开始 最后一步一定要调用这个属性 否则不生效
 */
- (WTableView *(^)(void))wStart{
    return ^WTableView*(){
        if (self.config) {
            if (@available(iOS 11.0, *)) {
                self.estimatedSectionFooterHeight = 0.01;
                self.estimatedSectionHeaderHeight = 0.01;
            }
            self.rowHeight = UITableViewAutomaticDimension;
            self.estimatedRowHeight = 100.0f;
            self.separatorStyle = UITableViewCellSeparatorStyleNone;
        }
        [self getData:self.pushData];
        if ([self reginerCell]) {
            self.delegate = self;
            self.dataSource = self;
        }
        
        return self;
    };
}


- (WTableView *(^)( UIView *, CGRect, NSMutableArray *))wFrameConfig{
    return ^WTableView*(UIView *wParent,CGRect wFrame,NSMutableArray* wDataArr){
        
        self.pushData = [NSMutableArray arrayWithArray:wDataArr];
        
        self.frame = wFrame;
        
        if (wParent) {
            [wParent addSubview:self];
        }
        return self;
    };
}


- (WTableView *(^)(UIView *, WConstraint, NSMutableArray *))WasonryConfig{
    return ^WTableView*(UIView *wParent,WConstraint Wasonry,NSMutableArray* wDataArr){
        
        self.pushData = [NSMutableArray arrayWithArray:wDataArr];
        
        if (wParent) {
            [wParent addSubview:self];
            if (Wasonry) {
                [self mas_makeConstraints:Wasonry];
            }
        }
        return self;
    };
}




- (WTableView *(^)(NSMutableArray *))wUpdateData{
    return ^WTableView*(NSMutableArray *changeData){
        if(changeData){
            if (self.isSection) {
                if (changeData.count == self.simpleDataArr.count) {
                    for (int i = 0; i<changeData.count; i++) {
                        [self compareData:changeData[i] beforeData:self.simpleDataArr[i] changeData:self.dataArr[i] withSection:i];
                    }
                }else{
                    /*
                     *暂时想不到有什么好的算法 直接刷新 要局部刷新需从外面刷新
                     */
                    [self getData:changeData];
                    [self reloadData];
                }
            }else{
                [self compareData:changeData beforeData:self.simpleDataArr changeData:self.dataArr withSection:0];
            }
            self.simpleDataArr = [NSMutableArray arrayWithArray:changeData];

        }
        return self;
    };
}

- (WTableView *(^)(WCellCallBlock))wDealCell{
    return ^WTableView*(WCellCallBlock wDealCell){
        if (wDealCell) {
            self.cellBlock = wDealCell;
        }
        return self;
    };
}



- (WTableView *(^)(WSelectCallBlock))wDidSelect{
    return ^WTableView*(WSelectCallBlock wDidSelect){
        if (wDidSelect) {
            self.selectBlock = wDidSelect;
        }
        return self;
    };
}


- (WTableView *(^)(WCellHeight))wCellHeight{
    return ^WTableView*(WCellHeight block){
        if (block) {
            self.cellHeightBlock = block;
        }
        return self;
    };
}



/*
 * 设置cell头视图高度
 */
- (WTableView *(^)(WCellHeadHeight))wCellHeadHeight{
    return ^WTableView*(WCellHeadHeight block){
        if (block) {
            self.headHeightBlock = block;
        }
        return self;
    };
}

/*
 * 设置cell尾视图高度
 */
- (WTableView *(^)(WCellFootHeight))wCellFootHeight{
    return ^WTableView*(WCellFootHeight block){
        if (block) {
            self.footHeightBlock = block;
        }
        return self;
    };
}

/*
 * 设置cell头视图样式
 */
- (WTableView *(^)(WCellHeadView))wCellHeadView{
    return ^WTableView*(WCellHeadView block){
        if (block) {
            self.headViewBlock = block;
        }
        return self;
    };
}


/*
 * 设置cell尾视图样式
 */
- (WTableView *(^)(WCellFootView))wCellFootView{
    return ^WTableView*(WCellFootView block){
        if (block) {
            self.footViewBlock = block;
        }
        return self;
    };
}

/*
 * other代理
 */

- (WTableView *(^)(id<WTableViewDelegate>))wOtherDelegate{
    return ^WTableView*(id<WTableViewDelegate> wOtherDelegate){
        if (wOtherDelegate) {
            self.Wdelegate = wOtherDelegate;
        }
        return self;
    };
}

- (WTableView *(^)(BOOL))wSection{
    return ^WTableView*(BOOL wSection){
        self.isSection = wSection;
        
        return self;
    };
}


- (WTableView *(^)(BOOL))wCellAnaiml{
    return ^WTableView*(BOOL wCellAnaiml){
        self.scrolAnimal = wCellAnaiml;
        return self;
    };
}


- (WTableView *(^)(BOOL))wAutoCell{
    return ^WTableView*(BOOL wAutoCell){
        self.cellKVC = wAutoCell;
        return self;
    };
}

- (WTableView *(^)(BOOL))wConfig{
    return ^WTableView*(BOOL wConfig){
        self.config = wConfig;
        return self;
    };
}

/*
 *赋值数据
 */
- (void)getData:(NSMutableArray*)data{
    
    if (data) {
        //深拷贝 包括数组内的元素
        if (self.isSection) {
            self.dataArr = [NSMutableArray new];
            self.simpleDataArr = [NSMutableArray new];
            for (NSArray *copyArr in data) {
                [self.dataArr addObject:[[NSMutableArray alloc] initWithArray:[copyArr mutableCopy] copyItems:YES]];
            }
            
            //深拷贝 数组内的元素不深拷贝
            for (NSArray *copyArr in data) {
                [self.simpleDataArr addObject:[copyArr mutableCopy]];
            }
            
        }else{
            self.dataArr = [[NSMutableArray alloc] initWithArray:data copyItems:YES];
            //普通赋值
            self.simpleDataArr = [NSMutableArray arrayWithArray:data];
        }

        
    }
    
}

/*
 *注册cell
 */
- (BOOL)reginerCell{
    if (!self.cellKVC) return YES;
    
    self.cellNameArr = [NSMutableArray new];
    
    if (self.isSection ) {
        for (NSArray *arr in self.dataArr) {
            if(![arr isKindOfClass:[NSArray class]]||![arr isKindOfClass:[NSMutableArray class]]){
                NSLog(@"请输入正确的数据源 格式为@[@[],@[],@[]]");
                return NO;
            }
            for (wBaseModel *model in arr) {
                if ([self.cellNameArr indexOfObject:model.cellName]!=NSNotFound) continue;
                if (model.cellName) [self.cellNameArr addObject:model.cellName];
            }
        }
        
    }else{
        for (wBaseModel *model in self.dataArr) {
            if(![model isKindOfClass:[wBaseModel class]]){
                NSLog(@"请输入正确的数据源 格式为@[wBaseModel,wBaseModel,wBaseModel]");
                return NO;
            }
            if ([self.cellNameArr indexOfObject:model.cellName]!=NSNotFound) continue;
            if (model.cellName) [self.cellNameArr addObject:model.cellName];
        }
    }
    for (NSString *cellName in self.cellNameArr) {
        if (cellName) {
            //处理是否带有xib  有xib就是注册nib  没有注册Class
            NSString * nibPath = [[NSBundle mainBundle]pathForResource:cellName ofType:@"nib"];
            if (nibPath) {
               [self registerNib:[UINib nibWithNibName:cellName bundle:nil] forCellReuseIdentifier:cellName];
            }else{
                Class cellClass = NSClassFromString(cellName);
                [self registerClass:[cellClass class] forCellReuseIdentifier:cellName];
            }
        }
    }
    
    return YES;
}

/*
 *对比改变后的数据源与原来的数据源 并刷新 row
 */
- (void)compareData:(NSMutableArray*)data beforeData:(NSMutableArray*)beforeData changeData:(NSMutableArray*)nornalData withSection:(NSInteger)section{
    TICK
    //更新的块
    NSMutableArray *changePathArr = [NSMutableArray new];
    //添加的块
    NSMutableArray *insertPathArr = [NSMutableArray new];
    //删除的块
    NSMutableArray *deletePathArr = [NSMutableArray new];
    
    //取出相同的
    NSMutableArray *sameArr = [NSMutableArray new];
    //找出beforeData中有 data没有的
    NSMutableArray *differentArr = [NSMutableArray new];
    //找出data中有 beforeData没有的
    NSMutableArray *addArr = [NSMutableArray new];
    
    
    
    for (int i = 0; i<beforeData.count; i++) {
        id model = beforeData[i];
        
        if ([data indexOfObject:model] != NSNotFound) {
            //找出相等的
            [sameArr addObject:@{
                                 @"index":@(i),
                                 @"model":model
                                 }];
        }else{
            //找出self.simpleDataArr中有 data没有的
            [differentArr addObject:@{
                                      @"index":@(i),
                                      @"model":model
                                      }];
        }
    }
    
    
    for (int i = 0; i<data.count; i++) {
        id model = data[i];
        //找出data中有 self.simpleDataArr没有的
        if ([beforeData indexOfObject:model] == NSNotFound) {
            [addArr addObject:@{
                                @"index":@(i),
                                @"model":model
                                }];
        }
    }
    
    
    NSMutableArray *changeArr = [self compareModelArr:sameArr beforeData:nornalData];
    
    //局部刷新
    if (changeArr.count>0) {
        
        for (int i = 0; i< changeArr.count; i++) {
            NSDictionary *dic = changeArr[i];
            id changeModel = dic[@"changeModel"];
            
            NSInteger index = [dic[@"index"] integerValue];
            //重新复制
            [nornalData replaceObjectAtIndex:index withObject:[changeModel copy]];
            
            [self reSetCellName:[changeModel valueForKey:@"cellName"]];
            
            NSIndexPath *path = [NSIndexPath indexPathForRow:index inSection:section];
            [changePathArr addObject:path];
        }
        
        
        if (changePathArr.count>0) {
            [self reloadRowsAtIndexPaths:[NSArray arrayWithArray:changePathArr] withRowAnimation:UITableViewRowAnimationNone];
        }
        
    }
    
    if (differentArr.count>0) {
        //倒序删除 防止数组在删除的时候index发生改变 导致删除错误或崩溃
        for (int i = (int)differentArr.count-1; i>= 0; i--) {
            NSDictionary *dic = differentArr[i];
            NSInteger index = [dic[@"index"] integerValue];
            
            [nornalData removeObjectAtIndex:index];
            
            NSIndexPath *path = [NSIndexPath indexPathForRow:index inSection:section];
            [deletePathArr addObject:path];
        }
        //局部删除
        if (deletePathArr.count>0) {
            [self deleteRowsAtIndexPaths:[NSArray arrayWithArray:deletePathArr] withRowAnimation:UITableViewRowAnimationNone];
        }
    }
    
    if (addArr.count > 0) {
        for (int i = 0; i< addArr.count; i++) {
            NSDictionary *dic = addArr[i];
            id changeModel = dic[@"model"];
            NSInteger index = [dic[@"index"] integerValue];
            if (nornalData.count>index) {
                [nornalData insertObject:[changeModel copy] atIndex:index];
            }else{
                [nornalData addObject:[changeModel copy]];
            }
            
            [self reSetCellName:[changeModel valueForKey:@"cellName"]];
            NSIndexPath *path = [NSIndexPath indexPathForRow:index inSection:section];
            [insertPathArr addObject:path];
        }
        
        
        //局部增加
        if (insertPathArr.count>0) {
            [self insertRowsAtIndexPaths:[NSArray arrayWithArray:insertPathArr] withRowAnimation:UITableViewRowAnimationNone];
        }
    }
    
    TOCK

}




//注册未注册过的cellName
- (void)reSetCellName:(NSString*)cellName{
    if (cellName&&[cellName isKindOfClass:[NSString class]]) {
        if ([self.cellNameArr indexOfObject:cellName] == NSNotFound) {
            [self.cellNameArr addObject:cellName];
            //处理是否带有xib  有xib就是注册nib  没有注册Class
            NSString * nibPath = [[NSBundle mainBundle]pathForResource:cellName ofType:@"nib"];
            if (nibPath) {
                [self registerNib:[UINib nibWithNibName:cellName bundle:nil] forCellReuseIdentifier:cellName];
            }else{
                Class cellClass = NSClassFromString(cellName);
                [self registerClass:[cellClass class] forCellReuseIdentifier:cellName];
            }
        }
    }else{
        NSLog(@"请输入正确的数据");
    }
}

//对比model是否属性改变过
-(NSMutableArray*)compareModelArr:(NSArray*)sameArr beforeData:(NSMutableArray*)nornalData{
    NSMutableArray *changeArr = [NSMutableArray new];
    if (sameArr.count == 0) {
        return changeArr;
    }
    for (int i = 0; i<sameArr.count; i++) {
        NSDictionary *dic = sameArr[i];
        NSInteger index = [dic[@"index"] integerValue];
        //改变前
        id model = nornalData[index];
        //改变后
        id compareModel = dic[@"model"];
        unsigned int modelCount, compareModelCount;
        //分别获取所有属性
        objc_property_t * modelProperties = class_copyPropertyList([model class], &modelCount);
        objc_property_t * compareModelProperties = class_copyPropertyList([compareModel class], &compareModelCount);
        
        if (modelCount != compareModelCount) {
            NSLog(@"不相等,两个元素发生了改变");
            [changeArr addObject:@{
                                   @"index":@(index),
                                   @"model":model,
                                   @"changeModel":compareModel
                                   }];
            continue;
        }else{
            
            for (int j = 0; j < modelCount; j++) {
                objc_property_t property1 =modelProperties[j];
                objc_property_t property2 =compareModelProperties[j];
                NSString *propertyName1 = [[NSString alloc] initWithCString:property_getName(property1) encoding:NSUTF8StringEncoding];
                NSString *propertyName2 = [[NSString alloc] initWithCString:property_getName(property2) encoding:NSUTF8StringEncoding];
                //对比属性的值
                if ([model valueForKey:propertyName1]!=[compareModel valueForKey:propertyName2]) {
                    [changeArr addObject:@{
                                      @"index":@(index),
                                      @"model":model,
                                      @"changeModel":compareModel
                                      }];
                    break;
                }
            }
        }
        if (modelProperties)
            free(modelProperties);
        if (compareModelProperties)
            free(compareModelProperties);
        
        
    }
    return changeArr;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath{
    if (self.cellHeightBlock) {
        return self.cellHeightBlock(indexPath,tableView);
    }
    return UITableViewAutomaticDimension;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView{
    return  self.isSection == CellTypeSections ? self.dataArr.count:1 ;

}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return self.isSection == CellTypeSections ? [self.dataArr[section] count]:self.dataArr.count ;

}

- (UIView*)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section{
    if (self.footViewBlock) {
        return self.footViewBlock(section,tableView);
    }
    return [UIView new];
}


- (UIView*)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section{
    if (self.headViewBlock) {
        return self.headViewBlock(section,tableView);
    }
    return [UIView new];
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section{

    if (self.footHeightBlock) {
        return self.footHeightBlock(section,tableView);
    }
    return 0.01;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section{
    if (self.headHeightBlock) {
        return self.headHeightBlock(section,tableView);
    }
    return 0.01;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    
    wBaseModel *model = (self.isSection == CellTypeSections?self.dataArr[indexPath.section][indexPath.row]:self.dataArr[indexPath.row]);
    if (self.cellKVC) {
        if (model) {
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:model.cellName];
            [cell setValue:model forKey:@"model"];
            return cell;
        }
    }else{
        if (self.cellBlock) {
            return self.cellBlock(indexPath,tableView,model);
        }
    }
    return [UITableViewCell new];

}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    
    if (self.selectBlock) {
         wBaseModel *model = (self.isSection == CellTypeSections?self.dataArr[indexPath.section][indexPath.row]:self.dataArr[indexPath.row]);
         self.selectBlock(indexPath,tableView,model);
    }
}





- (void)scrollViewDidScroll:(UIScrollView *)scrollView{
    if (self.Wdelegate && [self.Wdelegate respondsToSelector:@selector(WScrollViewDidScroll:)]) {
        [self.Wdelegate WScrollViewDidScroll:scrollView];
    }
}

- (NSString*)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section{
    if (self.Wdelegate && [self.Wdelegate respondsToSelector:@selector(WTableViewTitleForFooterInSection:)]) {
        return [self.Wdelegate WTableViewTitleForFooterInSection:section];
    }
    return nil;
}

- (NSString*)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section{
    if (self.Wdelegate && [self.Wdelegate respondsToSelector:@selector(WTableViewTitleForHeaderInSection:)]) {
        return [self.Wdelegate WTableViewTitleForHeaderInSection:section];
    }
    return nil;
}

-(UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath{
    if (self.Wdelegate && [self.Wdelegate respondsToSelector:@selector(WTableViewEditingStyleForRowAtIndexPath:)]) {
        return [self.Wdelegate WTableViewEditingStyleForRowAtIndexPath:indexPath];
    }
    return UITableViewCellEditingStyleNone;
}

-(NSString *)tableView:(UITableView *)tableView titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.Wdelegate && [self.Wdelegate respondsToSelector:@selector(WTableViewTitleForDeleteConfirmationButtonForRowAtIndexPath:)]) {
        return [self.Wdelegate WTableViewTitleForDeleteConfirmationButtonForRowAtIndexPath:indexPath];
    }
    return nil;
}

- (void)tableView:(UITableView*)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath*)indexPath {
    if (self.Wdelegate && [self.Wdelegate respondsToSelector:@selector(WTableViewCommitEditingStyle:forRowAtIndexPath:)]) {
        return [self.Wdelegate WTableViewCommitEditingStyle:editingStyle forRowAtIndexPath:indexPath];
    }
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath{
    
    if (self.scrolAnimal) {
        cell.layer.transform = CATransform3DMakeScale(0.1, 0.1, 1);
        //还原
        [UIView animateWithDuration:1 animations:^{
            cell.layer.transform = CATransform3DIdentity;
        }];
    }
    
    if (self.Wdelegate && [self.Wdelegate respondsToSelector:@selector(WTableViewWillDisplayCell:forRowAtIndexPath:)]) {
        return [self.Wdelegate WTableViewWillDisplayCell:cell forRowAtIndexPath:indexPath];
    }
}




- (void)tableView:(UITableView *)tableView willBeginEditingRowAtIndexPath:(NSIndexPath *)indexPath{
    if (self.Wdelegate && [self.Wdelegate respondsToSelector:@selector(WTableView:willBeginEditingRowAtIndexPath:)]) {
        return [self.Wdelegate WTableView:tableView willBeginEditingRowAtIndexPath:indexPath];
    }
}

- (void)tableView:(UITableView *)tableView didEndEditingRowAtIndexPath:(NSIndexPath *)indexPath{
    if (self.Wdelegate && [self.Wdelegate respondsToSelector:@selector(WTableView:didEndEditingRowAtIndexPath:)]) {
        return [self.Wdelegate WTableView:tableView didEndEditingRowAtIndexPath:indexPath];
    }
}


- (NSArray<UITableViewRowAction *> *)tableView:(UITableView *)tableView editActionsForRowAtIndexPath:(NSIndexPath *)indexPath{
    if (self.Wdelegate && [self.Wdelegate respondsToSelector:@selector(WTableView:editActionsForRowAtIndexPath:)]) {
        return [self.Wdelegate WTableView:tableView editActionsForRowAtIndexPath:indexPath];
    }
    return nil;
}




- (void)dealloc{
//    [self removeObserver:self forKeyPath:@"dataArr"];
}

@end


@implementation wBaseModel
- (id)copyWithZone:(NSZone *)zone{
    wBaseModel *model = [wBaseModel new];
    model.cellName = _cellName;
    return model;
}
@end


@implementation wBaseCell

@end

