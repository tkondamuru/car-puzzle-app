import React, { useState, useEffect, useRef } from 'react';
import { useParams, useNavigate, Link } from 'react-router-dom';
import { Button } from '../components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '../components/ui/card';
import { Badge } from '../components/ui/badge';
import { ArrowLeft, RotateCcw, Clock, Trophy, Sparkles, Loader2 } from 'lucide-react';
import { toast } from 'sonner';
import { getPuzzleById, fetchPuzzles } from '../utils/mockData';
import { savePuzzleCompletion, getStoredStats } from '../utils/localStorage';
import { SVG } from '@svgdotjs/svg.js';

const PuzzlePage = () => {
  const { id } = useParams();
  const navigate = useNavigate();
  const [puzzle, setPuzzle] = useState(null);
  const [loading, setLoading] = useState(true);
  const [svgLoading, setSvgLoading] = useState(true);
  const [gameState, setGameState] = useState('playing'); // 'playing', 'completed'
  const startTimeRef = useRef(null); // Use a ref to persist the start time across re-renders
  const [currentTime, setCurrentTime] = useState(0);
  const [finalCompletionTime, setFinalCompletionTime] = useState('00:00');
  const [finalCompletionSeconds, setFinalCompletionSeconds] = useState(0);
  const [recommendedPuzzles, setRecommendedPuzzles] = useState([]);
  
  // SVG related refs and state
  const svgContainerRef = useRef(null);
  const svgInstanceRef = useRef(null);
  const partsRef = useRef({});
  const floatThumbRef = useRef({});

  const celebrationMessages = [
    "🎉 Complete! 🎉", "🌟 Awesome! 🌟", "🎯 Nailed It!", "🏁 You Did It!",
    "🚀 Well Done!", "🥳 Great Job!", "💫 Puzzle Solved!", "🔥 That Was Fast!",
    "🎈 Fantastic!", "✅ All Set!", "💥 Boom! Complete!", "👏 Bravo!",
    "🧠 Smart Move!", "🎮 Victory!", "✨ Excellent Work!", "🎊 You Rock!",
    "🎵 That Was Smooth!", "🍭 Sweet Success!", "🧩 Puzzle Master!",
    "🌈 Magic Move!", "🏆 Champion!", "🎨 Masterpiece!", "🎤 Mic Drop!",
    "😎 Too Cool!", "🔓 Unlocked!", "🦄 Nailed the Magic!", "🥇 First Place!",
    "🌟 Superstar!", "🛸 Out of This World!"
  ];

  useEffect(() => {
    loadPuzzle();
    loadRecommendedPuzzles();
  }, [id]);

  useEffect(() => {
    if (puzzle && puzzle.imgUrl) {
      if (startTimeRef.current === null) {
        startTimeRef.current = Date.now(); // Set start time using ref when puzzle is loaded
      }
      loadSVGContent();
    }
  }, [puzzle]);

  useEffect(() => {
    // Start timer when puzzle loads and game is playing
    if (puzzle && gameState === 'playing') {
      const timer = setInterval(() => {
        if (startTimeRef.current) {
          setCurrentTime(Math.floor((Date.now() - startTimeRef.current) / 1000));
        }
      }, 1000);
      return () => clearInterval(timer);
    }
  }, [puzzle, gameState]); // Depend on puzzle and gameState

  const loadPuzzle = async () => {
    try {
      setLoading(true);
      const puzzleData = await getPuzzleById(id);
      setPuzzle(puzzleData);
    } catch (error) {
      console.error('Error loading puzzle:', error);
      toast.error('Failed to load puzzle');
    } finally {
      setLoading(false);
    }
  };

  
  const loadRecommendedPuzzles = async () => {
    try {
      const allPuzzles = await fetchPuzzles();
      const stats = getStoredStats();
      
      // Filter out current puzzle
      const otherPuzzles = allPuzzles.filter(p => p.id !== id);
      
      // Separate completed and incomplete puzzles
      const incompletePuzzles = otherPuzzles.filter(p => !stats.completedPuzzles.includes(p.id));
      const completedPuzzles = otherPuzzles.filter(p => stats.completedPuzzles.includes(p.id));
      
      // Shuffle function
      const shuffle = (array) => {
        const shuffled = [...array];
        for (let i = shuffled.length - 1; i > 0; i--) {
          const j = Math.floor(Math.random() * (i + 1));
          [shuffled[i], shuffled[j]] = [shuffled[j], shuffled[i]];
        }
        return shuffled;
      };
      
      // Get random recommendations (prioritize incomplete puzzles)
      const shuffledIncomplete = shuffle(incompletePuzzles);
      const shuffledCompleted = shuffle(completedPuzzles);
      
      // Take up to 4 puzzles, prioritizing incomplete ones
      const recommended = [
        ...shuffledIncomplete.slice(0, 4),
        ...shuffledCompleted.slice(0, Math.max(0, 4 - shuffledIncomplete.length))
      ].slice(0, 4);
      
      setRecommendedPuzzles(recommended);
    } catch (error) {
      console.error('Error loading recommended puzzles:', error);
    }
  };

  const loadSVGContent = async () => {
    try {
      setSvgLoading(true);
      const response = await fetch(puzzle.imgUrl);
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }
      
      const svgText = await response.text();
      
      if (svgContainerRef.current) {
        // Clear previous content
        svgContainerRef.current.innerHTML = '';
        
        // Inject SVG content
        svgContainerRef.current.innerHTML = svgText;
        
        // Make SVG responsive by removing fixed width and height
        const svgElement = svgContainerRef.current.querySelector('svg');
        if (svgElement) {
          // Remove fixed dimensions
          svgElement.removeAttribute('width');
          svgElement.removeAttribute('height');
          
          // Add responsive styling
          svgElement.style.width = '100%';
          svgElement.style.height = 'auto';
          svgElement.style.maxHeight = '80vh';
          
          // Preserve aspect ratio if viewBox exists
          if (!svgElement.getAttribute('viewBox')) {
            // If no viewBox, try to set one based on original dimensions
            const originalWidth = svgElement.getAttribute('data-width') || '800';
            const originalHeight = svgElement.getAttribute('data-height') || '600';
            svgElement.setAttribute('viewBox', `0 0 ${originalWidth} ${originalHeight}`);
          }
          
          // Ensure it's scalable
          svgElement.setAttribute('preserveAspectRatio', 'xMidYMid meet');
        }
        
        // Initialize SVG.js after content is loaded and made responsive
        setTimeout(() => {
          initializeSVGInteraction();
        }, 300);
      }
    } catch (error) {
      console.error('Error loading SVG:', error);
      toast.error('Failed to load puzzle image');
      // Fallback to emoji display
      if (svgContainerRef.current) {
        svgContainerRef.current.innerHTML = `
          <div style="display: flex; align-items: center; justify-content: center; height: 400px; font-size: 8rem;">
            ${puzzle.emoji}
          </div>
        `;
      }
    } finally {
      setSvgLoading(false);
    }
  };

  const getSVGCoordsFromEvent = (e) => {
    const clientX = e.touches ? e.touches[0].clientX : e.clientX;
    const clientY = e.touches ? e.touches[0].clientY : e.clientY;
    return svgInstanceRef.current.point(clientX, clientY);
  };

  const setupDrag = (dragId) => {
    try {
      const thumb = SVG(`#rt${dragId}`);
      const target = SVG(`#g${dragId}`);
      
      if (!thumb || !thumb.node || !target || !target.node) {
        console.log(`Drag elements for ${dragId} not found, skipping setup`);
        return;
      }
      
      const trayPos = thumb.cx();
      const trayY = thumb.cy();
      let floating = null;

      thumb.on('mousedown touchstart', (e) => {
        e.preventDefault();
        
        if (floatThumbRef.current['last'] != null) {
          floatThumbRef.current['last'].remove();
          floatThumbRef.current['last'] = null;
        }
        
        const { x: startX, y: startY } = getSVGCoordsFromEvent(e);
        floating = target.clone().addTo(svgInstanceRef.current).opacity(0.4).front();
        floating.center(startX, startY);
        floating.show();
        floatThumbRef.current['last'] = floating;

        function moveHandler(ev) {
          const { x, y } = getSVGCoordsFromEvent(ev);
          floating.center(x, y);
        }

        function upHandler(ev) {
          document.removeEventListener("mousemove", moveHandler);
          document.removeEventListener("mouseup", upHandler);
          document.removeEventListener('touchmove', moveHandler);
          document.removeEventListener('touchend', upHandler);

          const dist = Math.hypot(
            floating.cx() - partsRef.current[dragId].center.x,
            floating.cy() - partsRef.current[dragId].center.y
          );

          // Removed debug text display

          if (dist < 50) {
            target.show();
            floating.remove();
            thumb.parent().hide();
            
            // Check if all thumbs are hidden
            const remaining = svgInstanceRef.current.find('[id^=rt]').filter(el => el.parent().visible());
            if (remaining.length === 0) {
              showPuzzleComplete();
            }
          } else {
            floating.animate(300).center(trayPos, trayY).after(() => {
              floating.remove();
            });
          }
        }

        document.addEventListener("mousemove", moveHandler);
        document.addEventListener("mouseup", upHandler);
        document.addEventListener("touchmove", moveHandler);
        document.addEventListener("touchend", upHandler);
      });
    } catch (error) {
      console.log(`Error setting up drag for ${dragId}:`, error.message);
    }
  };

  const initAllDraggables = () => {
    const maxGroupCount = getDynamicGroupCount();
    
    for (let i = 1; i <= maxGroupCount; i++) {
      try {
        const target = SVG(`#g${i}`);
        if (!target || !target.node) {
          console.log(`Target g${i} not found, skipping`);
          continue;
        }
        
        const bbox = target.bbox();
        partsRef.current[i] = {
          target: target,
          center: { x: bbox.cx, y: bbox.cy }
        };
        
        setupDrag(i);
        target.hide();
      } catch (error) {
        console.log(`Error setting up draggable ${i}:`, error.message);
      }
    }
  };

  const showPuzzleComplete = () => {
    try {
      const puzzleRoot = SVG('#puzzleSvg'); // Fixed: use puzzleSvg instead of puzzleRoot
      if (!puzzleRoot || !puzzleRoot.node) {
        console.log('puzzleSvg not found, completing puzzle without animation');
        completePuzzle();
        return;
      }

      // Shine animation: pulse scale + opacity
      puzzleRoot.animate(600, '<>')
        .scale(0.95)
        .opacity(0.9)
        .loop(3, true)
        .after(() => {
          puzzleRoot.animate(600).scale(1).opacity(1);
          const message = celebrationMessages[Math.floor(Math.random() * celebrationMessages.length)];
          
          svgInstanceRef.current.text(message)
            .move(150, 30)
            .font({ size: 35, anchor: 'middle', weight: 'bold', family: 'Comic Sans MS, cursive' })
            .fill('#28a745')
            .animate(1000).opacity(1);
          
          // Complete puzzle in React state
          completePuzzle();
        });
    } catch (error) {
      console.log('Error in showPuzzleComplete:', error.message);
      completePuzzle();
    }
  };

  const getDynamicGroupCount = () => {
    if (!svgInstanceRef.current) return 0;
    
    try {
      // Find all groups with IDs starting with 'g' followed by numbers
      const groups = svgInstanceRef.current.find('[id^="g"]').filter(el => {
        const id = el.attr('id');
        return id && /^g\d+$/.test(id); // matches g1, g2, g3, etc.
      });
      
      const groupNumbers = groups.map(el => {
        const id = el.attr('id');
        return parseInt(id.replace('g', ''));
      }).filter(num => !isNaN(num));
      
      return groupNumbers.length > 0 ? Math.max(...groupNumbers) : 0;
    } catch (error) {
      console.log('Error getting dynamic group count:', error.message);
      return 0;
    }
  };

  const addThumbHitboxes = () => {
    const maxGroupCount = getDynamicGroupCount();
    console.log(`Found ${maxGroupCount} puzzle groups`);
    
    for (let i = 1; i <= maxGroupCount; i++) {
      try {
        const group = SVG(`#t${i}`);
        if (!group || !group.node) continue;

        const bbox = group.bbox();
        const padding = 5;

        const bg = svgInstanceRef.current.rect(
          bbox.width + padding * 2,
          bbox.height + padding * 2
        )
          .move(bbox.x - padding, bbox.y - padding)
          .fill('#fff')
          .opacity(0.01)
          .attr({ id: `rt${i}` })
          .back();

        group.add(bg);
      } catch (error) {
        console.log(`Skipping group t${i} - not found or error:`, error.message);
      }
    }
  };

  const initializeSVGInteraction = () => {
    try {
      // Find the SVG element in the container
      const svgElement = svgContainerRef.current.querySelector('svg');
      if (!svgElement) {
        console.error('SVG element not found');
        return;
      }

      // Set an ID for SVG.js to target
      svgElement.id = 'puzzleSvg';
      
      // Initialize SVG.js with a small delay to ensure DOM is ready
      setTimeout(() => {
        try {
          svgInstanceRef.current = SVG('#puzzleSvg');
          
          // Initialize drag functionality (removed debugText)
          addThumbHitboxes();
          initAllDraggables();
          
          console.log('SVG interaction initialized successfully');
        } catch (initError) {
          console.error('Error in delayed SVG initialization:', initError);
        }
      }, 200);
      
    } catch (error) {
      console.error('Error initializing SVG interaction:', error);
    }
  };

  const formatTime = (seconds) => {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
  };

  const completePuzzle = () => {
    // Calculate actual elapsed time directly instead of relying on state
    if (startTimeRef.current === null) {
      console.error('Start time is null at puzzle completion');
      return;
    }
    
    const actualElapsedSeconds = Math.floor((Date.now() - startTimeRef.current) / 1000);
    const completionTime = formatTime(actualElapsedSeconds);

    console.log('Completing puzzle with time:', completionTime, 'seconds:', actualElapsedSeconds);
    console.log('State currentTime was:', currentTime, 'but actual elapsed is:', actualElapsedSeconds);
    console.log('StartTime was:', startTimeRef.current, 'Current time:', Date.now());

    // Store the final completion time for the modal
    setFinalCompletionTime(completionTime);
    setFinalCompletionSeconds(actualElapsedSeconds);
    setGameState('completed');
    
    // Save completion to localStorage using actual elapsed time
    const savedStats = savePuzzleCompletion(puzzle.id, completionTime, actualElapsedSeconds);
    console.log('Puzzle completion saved:', savedStats);
    
    toast.success(
      `🎉 Puzzle Completed! Time: ${completionTime}`,
      {
        duration: 4000,
        description: "Great job! You're becoming a puzzle master!"
      }
    );
  };

  const resetPuzzle = () => {
    setGameState('playing');
    startTimeRef.current = Date.now();
    setCurrentTime(0);
    setFinalCompletionTime('00:00');
    setFinalCompletionSeconds(0);
    
    // Reset SVG state
    if (svgInstanceRef.current) {
      // Clear any floating pieces
      if (floatThumbRef.current['last']) {
        floatThumbRef.current['last'].remove();
        floatThumbRef.current['last'] = null;
      }
      
      // Get dynamic group count and reset all parts
      const maxGroupCount = getDynamicGroupCount();
      for (let i = 1; i <= maxGroupCount; i++) {
        try {
          const target = SVG(`#g${i}`);
          const thumb = SVG(`#rt${i}`);
          if (target && target.node) target.hide();
          if (thumb && thumb.node) thumb.parent().show();
        } catch (error) {
          console.log(`Error resetting piece ${i}:`, error.message);
        }
      }
      
      // Clear any celebration text
      try {
        const textElements = svgInstanceRef.current.find('text').filter(el => 
          el.text && el.text() && celebrationMessages.includes(el.text())
        );
        textElements.forEach(el => el.remove());
      } catch (error) {
        console.log('Error clearing celebration text:', error.message);
      }
    }
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-purple-400 via-pink-400 to-orange-400 p-4 flex items-center justify-center">
        <Card className="p-8 text-center bg-white/95 backdrop-blur-sm">
          <Loader2 className="mx-auto mb-4 animate-spin text-purple-500" size={48} />
          <h2 className="text-2xl font-bold text-gray-800 mb-2">Loading Puzzle...</h2>
          <p className="text-gray-600">Getting your puzzle ready!</p>
        </Card>
      </div>
    );
  }

  if (!puzzle) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-purple-400 via-pink-400 to-orange-400 p-4 flex items-center justify-center">
        <Card className="p-8 text-center">
          <CardTitle className="text-2xl mb-4">Puzzle Not Found</CardTitle>
          <Button onClick={() => navigate('/')} className="bg-purple-500 hover:bg-purple-600">
            <ArrowLeft className="mr-2" size={16} />
            Back to Home
          </Button>
        </Card>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-purple-400 via-pink-400 to-orange-400 p-4">
      <div className="max-w-6xl mx-auto">
        {/* Header */}
        <div className="flex items-center justify-between mb-6">
          <Button
            onClick={() => navigate('/')}
            className="bg-white/20 backdrop-blur-sm hover:bg-white/30 text-white border border-white/30"
          >
            <ArrowLeft className="mr-2" size={16} />
            Back to Home
          </Button>
          
          <div className="flex items-center gap-4">
            <div className="bg-white/20 backdrop-blur-sm rounded-xl px-4 py-2 border border-white/30">
              <div className="flex items-center gap-2 text-white font-semibold">
                <Clock size={20} />
                {formatTime(currentTime)}
              </div>
            </div>
            
            <Button
              onClick={resetPuzzle}
              className="bg-white/20 backdrop-blur-sm hover:bg-white/30 text-white border border-white/30"
            >
              <RotateCcw className="mr-2" size={16} />
              Reset
            </Button>
          </div>
        </div>

        {/* Puzzle Info */}
        <Card className="mb-6 bg-white/95 backdrop-blur-sm border-2 border-white/50">
          <CardHeader>
            <div className="flex items-center justify-between">
              <div>
                <CardTitle className="text-2xl font-bold text-gray-800 mb-2">
                  {puzzle.title}
                </CardTitle>
                <p className="text-gray-600">{puzzle.description}</p>
              </div>
              <div className="text-6xl">{puzzle.emoji}</div>
            </div>
            <div className="flex items-center gap-2 mt-4">
              <Badge variant="secondary">{puzzle.difficulty}</Badge>
              <Badge variant="outline">{puzzle.pieces} pieces</Badge>
              {gameState === 'completed' && (
                <Badge className="bg-green-500 text-white">
                  <Trophy size={12} className="mr-1" />
                  Completed!
                </Badge>
              )}
            </div>
          </CardHeader>
        </Card>

        {/* Interactive SVG Puzzle */}
        <Card className="mb-6 bg-white/95 backdrop-blur-sm border-2 border-white/50">
          <CardHeader>
            <CardTitle className="text-xl font-bold text-gray-800">
              🧩 Assemble the Car — One Part at a Time!
            </CardTitle>
            <p className="text-gray-600 text-sm">
              Drag each part into place — if you miss, we'll show you where it belongs!
            </p>
          </CardHeader>
          <CardContent>
            {svgLoading && (
              <div className="flex items-center justify-center h-96">
                <Loader2 className="animate-spin text-purple-500" size={48} />
                <span className="ml-4 text-gray-600">Loading interactive puzzle...</span>
              </div>
            )}
            <div 
              ref={svgContainerRef}
              className="svg-container rounded-lg border-2 border-dashed border-gray-300 overflow-hidden"
              style={{ display: svgLoading ? 'none' : 'block' }}
            />
          </CardContent>
        </Card>

        {/* Recommended Puzzles Section */}
        {recommendedPuzzles.length > 0 && (
          <Card className="mb-6 bg-white/95 backdrop-blur-sm border-2 border-white/50">
            <CardHeader>
              <CardTitle className="text-xl font-bold text-gray-800 flex items-center gap-2">
                <Sparkles className="text-purple-500" />
                Try These Puzzles Next!
              </CardTitle>
              <p className="text-gray-600 text-sm">
                More fun puzzles waiting for you to solve
              </p>
            </CardHeader>
            <CardContent>
              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
                {recommendedPuzzles.map((recommendedPuzzle) => {
                  const stats = getStoredStats();
                  const isCompleted = stats.completedPuzzles.includes(recommendedPuzzle.id);
                  const completionTime = stats.puzzleTimes[recommendedPuzzle.id];
                  
                  return (
                    <Card key={recommendedPuzzle.id} className="overflow-hidden transform hover:scale-105 hover:shadow-lg transition-all duration-300 bg-white border border-gray-200">
                      <CardHeader className="relative p-3">
                        <div className="absolute top-1 right-1">
                          {isCompleted && (
                            <Badge className="bg-green-500 text-white text-xs">
                              <Trophy size={8} className="mr-1" />
                              Solved!
                            </Badge>
                          )}
                        </div>
                        <CardTitle className="text-sm font-bold text-gray-800 mb-1 leading-tight">
                          {recommendedPuzzle.title}
                        </CardTitle>
                        <p className="text-gray-600 text-xs line-clamp-2">{recommendedPuzzle.description}</p>
                      </CardHeader>
                      <CardContent className="p-3 pt-0">
                        <div className="aspect-square bg-gradient-to-br from-blue-100 to-purple-100 rounded-lg mb-3 flex items-center justify-center border border-gray-200 overflow-hidden">
                          {recommendedPuzzle.imgUrl ? (
                            <img 
                              src={recommendedPuzzle.imgUrl} 
                              alt={recommendedPuzzle.title}
                              className="w-full h-full object-contain rounded-lg"
                              onError={(e) => {
                                e.target.style.display = 'none';
                                e.target.nextSibling.style.display = 'flex';
                              }}
                            />
                          ) : null}
                          <div className="text-3xl" style={{ display: recommendedPuzzle.imgUrl ? 'none' : 'flex' }}>
                            {recommendedPuzzle.emoji}
                          </div>
                        </div>
                        
                        <div className="flex items-center justify-between mb-3">
                          <div className="flex items-center gap-1">
                            <Badge variant="secondary" className="text-xs px-1 py-0">
                              {recommendedPuzzle.difficulty}
                            </Badge>
                            <Badge variant="outline" className="text-xs px-1 py-0">
                              {recommendedPuzzle.pieces}pc
                            </Badge>
                          </div>
                          {completionTime && (
                            <div className="flex items-center gap-1 text-xs text-gray-600">
                              <Clock size={8} />
                              {completionTime}
                            </div>
                          )}
                        </div>

                        {/* Tags Display */}
                        {recommendedPuzzle.tags && recommendedPuzzle.tags.length > 0 && (
                          <div className="flex flex-wrap gap-1 mb-3">
                            {recommendedPuzzle.tags.slice(0, 2).map(tag => (
                              <Badge key={tag} variant="outline" className="text-xs bg-blue-50 text-blue-700 px-1 py-0">
                                {tag.replace('-', ' ')}
                              </Badge>
                            ))}
                            {recommendedPuzzle.tags.length > 2 && (
                              <Badge variant="outline" className="text-xs px-1 py-0">
                                +{recommendedPuzzle.tags.length - 2}
                              </Badge>
                            )}
                          </div>
                        )}
                        
                        <Link to={`/puzzle/${recommendedPuzzle.id}`}>
                          <Button 
                            size="sm" 
                            className="w-full bg-gradient-to-r from-purple-500 to-pink-500 hover:from-purple-600 hover:to-pink-600 text-white font-semibold py-2 rounded-lg text-xs transform hover:scale-105 transition-all duration-200"
                          >
                            {isCompleted ? 'Play Again' : 'Try This!'}
                          </Button>
                        </Link>
                      </CardContent>
                    </Card>
                  );
                })}
              </div>
            </CardContent>
          </Card>
        )}

        {/* Completion Modal */}
        {gameState === 'completed' && (
          <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50">
            <Card className="m-4 max-w-md w-full bg-white/95 backdrop-blur-sm border-2 border-white/50">
              <CardHeader className="text-center">
                <div className="text-6xl mb-4">🎉</div>
                <CardTitle className="text-2xl font-bold text-gray-800 mb-2">
                  Puzzle Completed!
                </CardTitle>
                <p className="text-gray-600">
                  Amazing work! You solved the puzzle in {finalCompletionTime}.
                </p>
              </CardHeader>
              <CardContent className="text-center space-y-4">
                <div className="flex items-center justify-center gap-2 text-lg font-semibold text-green-600">
                  <Trophy size={24} />
                  New Achievement Unlocked!
                </div>
                <div className="flex gap-2 justify-center">
                  <Button
                    onClick={() => navigate('/')}
                    className="bg-purple-500 hover:bg-purple-600 text-white"
                  >
                    <ArrowLeft className="mr-2" size={16} />
                    Back to Home
                  </Button>
                  <Button
                    onClick={resetPuzzle}
                    className="bg-green-500 hover:bg-green-600 text-white"
                  >
                    <Sparkles className="mr-2" size={16} />
                    Play Again
                  </Button>
                </div>
              </CardContent>
            </Card>
          </div>
        )}
      </div>
    </div>
  );
};

export default PuzzlePage;