//
// Copyright (C) 2019 Muhammad Tayyab Akram
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import Foundation

struct GlyphStrike {
    var typeface: Typeface!
    var pixelWidth: FT_F26Dot6      // 26.6 fixed-point value.
    var pixelHeight: FT_F26Dot6     // 26.6 fixed-point value.
    var skewX: FT_Fixed             // 16.16 fixed-point value.

    init() {
        typeface = nil
        pixelWidth = 0
        pixelHeight = 0
        skewX = 0
    }
}
