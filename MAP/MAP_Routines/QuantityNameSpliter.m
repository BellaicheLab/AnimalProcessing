            function [Q1,Q2] = QuantityNameSpliter(Qname)
            Q1= Qname;
            Q2 = [];
            
            marker = strfind(Qname, 'dot');
            if ~isempty(marker)
                marker2 = strfind(Qname, '_');
                Q2      = Qname((marker2-2):marker2-1);
                Q1      = Qname(1:marker-1);
            end
            
            marker = strfind(Qname, 'plus');
            if ~isempty(marker)
                Q2 = Qname(marker+4:end);
                Q1 = Qname(1:marker-1);
            end
            
            marker = strfind(Qname, 'minus');
            if ~isempty(marker)
                Q2 = Qname(marker+5:end);
                Q1 = Qname(1:marker-1);
            end
            
            end