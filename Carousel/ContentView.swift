//
//  ContentView.swift
//  ImageCarouselView
//
//  Created by Pavel Zak on 19/10/2020.
//

import SwiftUI


struct CarouselViewEffect: AnimatableModifier {
    let numberOfViews: Int
    let pathRadius: CGFloat
    let rect: CGRect
    let viewIndex: Int
    var offsetValue: Double // 0...1
    
    var animatableData: Double {
        get { offsetValue }
        set { offsetValue = newValue }
    }
    
    func viewPosition(at index: Double, rect: CGRect) -> CGPoint {
        var indexNormalized = CGFloat(index.truncatingRemainder(dividingBy: Double(numberOfViews)))
        if indexNormalized<0 {
            indexNormalized += CGFloat(numberOfViews)
        }
        
        let imagePhases = self.imagePhases(num: numberOfViews)
        let basePhase = imagePhases[Int(indexNormalized)]
        
        var phaseRemainder = index.truncatingRemainder(dividingBy: 1)
        if phaseRemainder<0 {
            phaseRemainder += 1
        }
        let phaseLen = imagePhases[Int(indexNormalized+1)] - imagePhases[Int(indexNormalized)]
        let interpolatedRemainder = phaseRemainder * phaseLen
        return pathPosition(at: basePhase+interpolatedRemainder, rect: rect)
    }
    
    func viewScale(at index: Double, rect: CGRect) -> Double {
        var indexNormalized = CGFloat(index.truncatingRemainder(dividingBy: Double(numberOfViews)))
        if indexNormalized<0 {
            indexNormalized += CGFloat(numberOfViews)
        }
        
        let scalePhases = self.imageSizes(num: numberOfViews)
        var phaseRemainder = index.truncatingRemainder(dividingBy: 1)
        if (phaseRemainder<0) {
            phaseRemainder += 1
        }

        return scalePhases[Int(indexNormalized)]*(1.0-phaseRemainder) + phaseRemainder*scalePhases[Int(indexNormalized)+1]
    }
    
    func colorRotation() -> Double {
        return Double(viewIndex)/Double(numberOfViews)*Double.pi*2
    }
    
    func pathPosition(at phase: Double, rect: CGRect) -> CGPoint {
        var phaseNormalized = CGFloat(phase.truncatingRemainder(dividingBy: 5))
        if phaseNormalized<0 {
            phaseNormalized += CGFloat(5)
        }
        let lineSegment = rect.size.width-2*pathRadius
        
        var x:CGFloat = 0
        var y:CGFloat = rect.height
        
        if phaseNormalized>=0 && phaseNormalized<1 {
            x = phaseNormalized/2*lineSegment + pathRadius
            //y = rect.height - 2*pathRadius - sin(phaseNormalized/2*CGFloat.pi)*rect.height/2
            let p = phaseNormalized
            let easeInOut = p*p/(p*p + (1.0 - p)*(1.0 - p))
            y = rect.height - 2*pathRadius - easeInOut*rect.height/3
        }
        else if phaseNormalized>=1 && phaseNormalized<2 {
            x = phaseNormalized/2*lineSegment + pathRadius
            //y = rect.height - 2*pathRadius - sin(phaseNormalized/2*CGFloat.pi)*rect.height/2
            let p = 2-phaseNormalized
            let easeInOut = p*p/(p*p + (1.0 - p)*(1.0 - p))
            y = rect.height - 2*pathRadius - easeInOut*rect.height/3
        }
        else if phaseNormalized>3 && phaseNormalized<4 {
            x = rect.size.width - pathRadius - (phaseNormalized-3)*lineSegment
        }
        else if phaseNormalized>=4 {
            let angle = CGFloat.pi/2 + (phaseNormalized-4)*CGFloat.pi
            x = pathRadius + cos(angle)*pathRadius
            y = rect.height - pathRadius + sin(angle)*pathRadius
        }
        else { //2..<3
            let angle = -CGFloat.pi/2 + (phaseNormalized-2)*CGFloat.pi
            x = pathRadius + lineSegment + cos(angle)*pathRadius
            y = rect.height - pathRadius + sin(angle)*pathRadius
        }
        return CGPoint(x: x, y: y)
    }
    
    func imagePhases(num: Int) -> [Double] {
        guard num>3 else { return [] }
        
        var positions = [0.2, 1.0, 1.8]
        for i in 3..<num {
            let step = 1.0/Double(num-2)
            positions.append(3.0 + step*Double(i-2))
        }
        positions.append(5.2)
        return positions
    }
    
    func imageSizes(num: Int) -> [Double] {
        guard num>3 else { return [] }
        
        var sizes = [0.3, 1.0, 0.3]
        for _ in 3..<num {
            sizes.append(0.05)
        }
        sizes.append(0.3)
        return sizes
    }
    
    func effectValue(size: CGSize) -> ProjectionTransform {
        let position = self.viewPosition(at: self.offsetValue, rect: self.rect)
        let viewScale = CGFloat(self.viewScale(at: self.offsetValue, rect: self.rect))
        
        let affineTransform = CGAffineTransform(translationX: size.width*0.5, y: size.height*0.5)
            .translatedBy(x: position.x, y: position.y)
            .translatedBy(x: -size.width*0.5, y: -size.height*0.5)
            .scaledBy(x: viewScale, y: viewScale)
        
        return ProjectionTransform(affineTransform)
    }
    
    func body(content: Content) -> some View {
        let position = self.viewPosition(at: self.offsetValue, rect: self.rect)
        let viewScale = CGFloat(self.viewScale(at: self.offsetValue, rect: self.rect))
        let itemSize = rect.width/2
        let overlayOpacity = 1.0-Double(viewScale)
        
        let overlay = Color("OverlayColor")
                        .hueRotation(Angle(radians: self.colorRotation()))
                        .blendMode(.plusDarker)
                        .background(Color("OverlayBackground").opacity(overlayOpacity))
                        .opacity(overlayOpacity)
        
        return content
            .frame(width: itemSize, height: itemSize)
            .overlay(overlay)
            .clipShape(RoundedRectangle(cornerRadius: 16+itemSize*(1.0-viewScale)))
            .scaleEffect(viewScale)
            .position(position)
    }
}

let springAnimation = Animation.interpolatingSpring(mass: 0.1, stiffness: 20, damping: 1.5, initialVelocity: 0)

struct ImageCarouselView: View {
    let imageNames: [String]
    let pathRadius:CGFloat = 20.0
    
    @State var dragOffset: CGFloat = 0
    @State var baseOffset: CGFloat = 0
    @State var scrollOffset: CGFloat = 0
    @State var isDragging: Bool = false
    
    var numberOfViews: Int {
        return self.imageNames.count
    }
    
    private func normalizeDragValue(_ value: CGFloat, rectWidth: CGFloat) -> CGFloat {
        return value/((rectWidth-2*pathRadius)*0.4)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach (0..<numberOfViews) { index in
                    Image("\(index+1)")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .modifier(CarouselViewEffect(numberOfViews: numberOfViews, pathRadius: pathRadius, rect: geometry.frame(in: .local), viewIndex: index, offsetValue: Double(index) + Double(scrollOffset)))
                        .onTapGesture {
                            if !self.isDragging {
                                withAnimation(springAnimation){
                                    self.scrollOffset += 1
                                }
                            }
                        }
                }
            }
            .padding()
            //.background(Color.orange)
            .simultaneousGesture( DragGesture(minimumDistance: 1, coordinateSpace: .local)
                .onChanged { value in
                    self.dragOffset = self.normalizeDragValue(value.translation.width, rectWidth: geometry.size.width)
                    self.scrollOffset = baseOffset + dragOffset
                    self.isDragging = true
                }
                .onEnded { value in
                    withAnimation(springAnimation){
                        let predicted = self.baseOffset + self.normalizeDragValue(value.predictedEndTranslation.width, rectWidth: geometry.size.width)
                        self.scrollOffset = round(self.scrollOffset*0.7 + predicted*0.3)
                        self.baseOffset = self.scrollOffset
                        self.dragOffset = 0
                    }
                    self.isDragging = false
                }
            )
        }
    }
}

struct ContentView: View {
    let imageNames = Array(1..<9).map{ "\($0)" }
    var body: some View {
        VStack {
            Spacer()
            ImageCarouselView(imageNames: self.imageNames)
                .frame(width: 400, height: 250)
                //.background(Color.gray)
                .padding(100)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(LinearGradient(gradient: Gradient(colors: [Color.black, Color("Background")]), startPoint: UnitPoint(), endPoint: UnitPoint(x:0, y:1)))
    }
}
