-- lua/autofilename/init.lua                                
                                                            
local M = {}                                                
                                                            
-- 自動保存コマンドを定義                                   
function M.setup()                                          
    vim.api.nvim_create_user_command(                       
        'AutoSaveNote', -- コマンド名                       
        function(opts)                                      
            -- ここにファイル名自動生成と保存のロジックを記述します
            print("AutoSaveNoteコマンドが実行されました！") 
            -- 例: local generated_filename =               
-- M.generate_filename()                                       
            -- M.save_current_buffer(generated_filename)    
        end,                                                
        {                                                   
            -- オプション (例: -bang で強制実行、-args で引数を受け取るなど)
            -- ここでは引数なしでシンプルに定義             
--             desc =                                          
-- '現在のバッファを自動生成されたファイル名で保存',           
--             nargs = 0,                                      
        }                                                   
    )                                                       
end                                                         
                                                            
return M                                                    
