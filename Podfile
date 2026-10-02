platform :ios, '14.0'



def product_pods

    pod 'Swifty360Player', :path => '.'

    pod 'AMSMB2'

end



workspace 'Swifty360Player.xcworkspace'

project 'Sample/Sample.xcodeproj'



target 'Sample' do

    use_frameworks!

    inherit! :search_paths

    product_pods

end

